// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#include "local_controller_bridge.h"

#include <chrono>
#include <utility>

namespace remote_controller {

LocalControllerBridge::LocalControllerBridge(
    std::unique_ptr<backends::InputBackend> input_backend,
    std::unique_ptr<backends::VirtualControllerBackend> virtual_backend,
    std::string device_id)
    : input_backend_(std::move(input_backend)),
      virtual_backend_(std::move(virtual_backend)),
      device_id_(std::move(device_id)) {}

LocalControllerBridge::~LocalControllerBridge() { Stop(); }

Result LocalControllerBridge::Start() {
  {
    std::lock_guard lock(mutex_);
    if (snapshot_.state != SessionState::kCreated) {
      return Result::kInvalidState;
    }
  }

  if (!virtual_backend_->Create(
          [this](const backends::RumbleCommand& command) {
            OnRumble(command);
          })) {
    std::lock_guard lock(mutex_);
    snapshot_.state = SessionState::kFaulted;
    return Result::kBackendFailure;
  }

  {
    std::lock_guard lock(mutex_);
    snapshot_.state = SessionState::kRunning;
  }
  if (!input_backend_->Open(
          device_id_,
          [this](const protocol::GamepadStateV1& state) { OnState(state); },
          [this] { OnDisconnected(); })) {
    {
      std::lock_guard lock(mutex_);
      snapshot_.state = SessionState::kFaulted;
      snapshot_.current_state = {};
    }
    virtual_backend_->SubmitNeutralState();
    virtual_backend_->Destroy();
    return Result::kBackendFailure;
  }
  return Result::kOk;
}

Result LocalControllerBridge::Stop() {
  {
    std::lock_guard lock(mutex_);
    if (snapshot_.state == SessionState::kStopped) {
      return Result::kOk;
    }
    snapshot_.state = SessionState::kStopped;
    snapshot_.current_state = {};
  }
  input_backend_->Close();
  virtual_backend_->SubmitNeutralState();
  virtual_backend_->Destroy();
  return Result::kOk;
}

LocalControllerBridgeSnapshot LocalControllerBridge::Snapshot() const {
  std::lock_guard lock(mutex_);
  return snapshot_;
}

void LocalControllerBridge::OnState(
    const protocol::GamepadStateV1& state) noexcept {
  {
    std::lock_guard lock(mutex_);
    if (snapshot_.state != SessionState::kRunning) {
      return;
    }
  }

  if (!virtual_backend_->SubmitState(state)) {
    {
      std::lock_guard lock(mutex_);
      if (snapshot_.state == SessionState::kRunning) {
        snapshot_.state = SessionState::kFaulted;
        snapshot_.current_state = {};
      }
    }
    virtual_backend_->SubmitNeutralState();
    return;
  }

  const auto timestamp_us = static_cast<std::uint64_t>(
      std::chrono::duration_cast<std::chrono::microseconds>(
          std::chrono::steady_clock::now().time_since_epoch())
          .count());
  std::lock_guard lock(mutex_);
  if (snapshot_.state == SessionState::kRunning) {
    snapshot_.current_state = state;
    snapshot_.timestamp_us = timestamp_us;
    ++snapshot_.sample_count;
  }
}

void LocalControllerBridge::OnDisconnected() noexcept {
  {
    std::lock_guard lock(mutex_);
    if (snapshot_.state != SessionState::kRunning) {
      return;
    }
    snapshot_.state = SessionState::kDisconnected;
    snapshot_.current_state = {};
  }
  virtual_backend_->SubmitNeutralState();
}

void LocalControllerBridge::OnRumble(
    const backends::RumbleCommand& command) noexcept {
  {
    std::lock_guard lock(mutex_);
    if (snapshot_.state != SessionState::kRunning) {
      return;
    }
    snapshot_.low_frequency_motor = command.low_frequency_motor;
    snapshot_.high_frequency_motor = command.high_frequency_motor;
    ++snapshot_.rumble_count;
  }
  static_cast<void>(input_backend_->SetRumble(
      command.low_frequency_motor, command.high_frequency_motor));
}

}  // namespace remote_controller
