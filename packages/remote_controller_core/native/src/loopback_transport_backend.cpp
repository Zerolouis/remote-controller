// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#include "backends/loopback_transport_backend.h"

#include <utility>

namespace remote_controller::backends {

LoopbackTransportBackend::~LoopbackTransportBackend() { Stop(); }

bool LoopbackTransportBackend::StartClient(
    StateCallback state_callback, RumbleCallback rumble_callback,
    DisconnectCallback disconnect_callback) {
  return Start(std::move(state_callback), std::move(rumble_callback),
               std::move(disconnect_callback));
}

bool LoopbackTransportBackend::StartServer(
    StateCallback state_callback, RumbleCallback rumble_callback,
    DisconnectCallback disconnect_callback) {
  return Start(std::move(state_callback), std::move(rumble_callback),
               std::move(disconnect_callback));
}

bool LoopbackTransportBackend::Start(
    StateCallback state_callback, RumbleCallback rumble_callback,
    DisconnectCallback disconnect_callback) {
  std::lock_guard lock(mutex_);
  if (accepting_ || worker_.joinable() || !state_callback) {
    return false;
  }

  state_callback_ = std::move(state_callback);
  rumble_callback_ = std::move(rumble_callback);
  disconnect_callback_ = std::move(disconnect_callback);
  pending_states_.clear();
  stop_requested_ = false;
  accepting_ = true;
  worker_ = std::thread(&LoopbackTransportBackend::WorkerLoop, this);
  return true;
}

bool LoopbackTransportBackend::SendState(
    const protocol::GamepadStateV1& state, const std::uint64_t sequence,
    const std::uint64_t timestamp_us) {
  {
    std::lock_guard lock(mutex_);
    if (!accepting_) {
      return false;
    }
    const StateFrame frame{state, sequence, timestamp_us};
    if (!pending_states_.empty() &&
        pending_states_.back().state.button_flags == state.button_flags) {
      pending_states_.back() = frame;
    } else {
      if (pending_states_.size() >= kMaximumQueuedFrames) {
        return false;
      }
      pending_states_.push_back(frame);
    }
  }
  condition_.notify_one();
  return true;
}

bool LoopbackTransportBackend::SendRumble(const RumbleCommand& command) {
  RumbleCallback callback;
  {
    std::lock_guard lock(mutex_);
    if (!accepting_) {
      return false;
    }
    callback = rumble_callback_;
  }
  if (callback) {
    callback(command);
  }
  return true;
}

void LoopbackTransportBackend::Stop() noexcept { Shutdown(false); }

void LoopbackTransportBackend::SimulateDisconnect() noexcept { Shutdown(true); }

void LoopbackTransportBackend::Shutdown(const bool notify_disconnect) noexcept {
  DisconnectCallback disconnect_callback;
  {
    std::lock_guard lock(mutex_);
    if (!accepting_ && !worker_.joinable()) {
      return;
    }
    accepting_ = false;
    stop_requested_ = true;
    pending_states_.clear();
    if (notify_disconnect) {
      disconnect_callback = disconnect_callback_;
    }
  }
  condition_.notify_all();

  if (worker_.joinable()) {
    worker_.join();
  }

  {
    std::lock_guard lock(mutex_);
    state_callback_ = {};
    rumble_callback_ = {};
    disconnect_callback_ = {};
    stop_requested_ = false;
  }

  if (disconnect_callback) {
    disconnect_callback();
  }
}

void LoopbackTransportBackend::WorkerLoop() noexcept {
  for (;;) {
    StateFrame frame;
    StateCallback callback;
    {
      std::unique_lock lock(mutex_);
      condition_.wait(lock, [this] {
        return stop_requested_ || !pending_states_.empty();
      });
      if (stop_requested_) {
        return;
      }
      frame = pending_states_.front();
      pending_states_.pop_front();
      callback = state_callback_;
    }
    if (callback) {
      callback(frame);
    }
  }
}

}  // namespace remote_controller::backends
