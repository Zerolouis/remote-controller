// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#include "session.h"

#include <utility>

namespace remote_controller {

Session::Session(const std::chrono::milliseconds input_timeout)
    : input_timeout_(input_timeout),
      transport_(std::make_unique<backends::LoopbackTransportBackend>()),
      virtual_controller_(
          std::make_unique<backends::MemoryVirtualControllerBackend>()) {}

Session::~Session() { Stop(); }

Result Session::Start() {
  {
    std::lock_guard lock(mutex_);
    if (state_ != SessionState::kCreated) {
      return Result::kInvalidState;
    }
    if (!virtual_controller_->Create({})) {
      state_ = SessionState::kFaulted;
      return Result::kBackendFailure;
    }
    state_ = SessionState::kRunning;
    watchdog_exit_ = false;
  }

  const bool transport_started = transport_->StartServer(
      [this](const backends::StateFrame& frame) { OnStateFrame(frame); }, {},
      [this] { OnDisconnected(); });
  if (!transport_started) {
    std::lock_guard lock(mutex_);
    state_ = SessionState::kFaulted;
    virtual_controller_->SubmitNeutralState();
    virtual_controller_->Destroy();
    return Result::kBackendFailure;
  }

  watchdog_thread_ = std::thread(&Session::WatchdogLoop, this);
  return Result::kOk;
}

Result Session::SubmitState(const protocol::GamepadStateV1& state,
                            const std::uint64_t sequence,
                            const std::uint64_t timestamp_us) {
  {
    std::lock_guard lock(mutex_);
    if (state_ != SessionState::kRunning) {
      return Result::kInvalidState;
    }
    if (has_submitted_sequence_ && sequence <= highest_submitted_sequence_) {
      return Result::kStaleSequence;
    }
    has_submitted_sequence_ = true;
    highest_submitted_sequence_ = sequence;
  }

  if (!transport_->SendState(state, sequence, timestamp_us)) {
    OnDisconnected();
    return Result::kBackendFailure;
  }
  return Result::kOk;
}

SessionSnapshot Session::Snapshot() const {
  std::lock_guard lock(mutex_);
  return SessionSnapshot{
      state_,
      latest_sequence_,
      accepted_state_count_,
      neutralization_count_,
      last_input_timestamp_us_,
      output_state_,
  };
}

Result Session::SimulateDisconnect() {
  {
    std::lock_guard lock(mutex_);
    if (state_ != SessionState::kRunning) {
      return Result::kInvalidState;
    }
  }
  transport_->SimulateDisconnect();
  JoinWatchdog();
  return Result::kOk;
}

Result Session::Stop() {
  bool should_stop_transport = false;
  {
    std::lock_guard lock(mutex_);
    if (state_ == SessionState::kCreated) {
      state_ = SessionState::kStopped;
      return Result::kOk;
    }
    if (state_ == SessionState::kStopped) {
      return Result::kOk;
    }
    if (state_ == SessionState::kRunning) {
      state_ = SessionState::kStopped;
      NeutralizeLocked();
      should_stop_transport = true;
    } else if (state_ == SessionState::kDisconnected ||
               state_ == SessionState::kFaulted) {
      should_stop_transport = true;
    }
    watchdog_exit_ = true;
  }
  watchdog_condition_.notify_all();

  if (should_stop_transport) {
    transport_->Stop();
  }
  JoinWatchdog();
  virtual_controller_->Destroy();
  return Result::kOk;
}

void Session::OnStateFrame(const backends::StateFrame& frame) noexcept {
  std::lock_guard lock(mutex_);
  if (state_ != SessionState::kRunning ||
      (accepted_state_count_ != 0 && frame.sequence <= latest_sequence_)) {
    return;
  }
  if (!virtual_controller_->SubmitState(frame.state)) {
    state_ = SessionState::kFaulted;
    NeutralizeLocked();
    watchdog_exit_ = true;
    watchdog_condition_.notify_all();
    return;
  }

  output_state_ = frame.state;
  latest_sequence_ = frame.sequence;
  ++accepted_state_count_;
  last_input_timestamp_us_ = frame.timestamp_us;
  last_input_arrival_ = std::chrono::steady_clock::now();
  watchdog_armed_ = true;
  watchdog_condition_.notify_all();
}

void Session::OnDisconnected() noexcept {
  {
    std::lock_guard lock(mutex_);
    if (state_ != SessionState::kRunning) {
      return;
    }
    state_ = SessionState::kDisconnected;
    NeutralizeLocked();
    watchdog_exit_ = true;
  }
  watchdog_condition_.notify_all();
}

void Session::WatchdogLoop() noexcept {
  std::unique_lock lock(mutex_);
  while (!watchdog_exit_) {
    if (!watchdog_armed_) {
      watchdog_condition_.wait(
          lock, [this] { return watchdog_exit_ || watchdog_armed_; });
      continue;
    }

    const auto deadline = last_input_arrival_ + input_timeout_;
    if (watchdog_condition_.wait_until(lock, deadline) ==
            std::cv_status::timeout &&
        !watchdog_exit_ && watchdog_armed_ &&
        std::chrono::steady_clock::now() >= deadline) {
      NeutralizeLocked();
      watchdog_armed_ = false;
    }
  }
}

void Session::NeutralizeLocked() noexcept {
  virtual_controller_->SubmitNeutralState();
  output_state_ = {};
  ++neutralization_count_;
  watchdog_armed_ = false;
}

void Session::JoinWatchdog() noexcept {
  if (watchdog_thread_.joinable()) {
    watchdog_thread_.join();
  }
}

}  // namespace remote_controller
