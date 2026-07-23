// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#include "input_capture.h"

#include <algorithm>
#include <chrono>
#include <utility>

namespace remote_controller {

InputCapture::InputCapture(std::unique_ptr<backends::InputBackend> backend,
                           std::string device_id)
    : backend_(std::move(backend)), device_id_(std::move(device_id)) {}

InputCapture::~InputCapture() { Stop(); }

Result InputCapture::Start() {
  {
    std::lock_guard lock(mutex_);
    if (snapshot_.state != SessionState::kCreated) {
      return Result::kInvalidState;
    }
    snapshot_.state = SessionState::kRunning;
  }

  if (!backend_->Open(
          device_id_,
          [this](const protocol::GamepadStateV1& state) { OnState(state); },
          [this] { OnDisconnected(); })) {
    std::lock_guard lock(mutex_);
    snapshot_.state = SessionState::kFaulted;
    return Result::kBackendFailure;
  }
  return Result::kOk;
}

Result InputCapture::Stop() {
  {
    std::lock_guard lock(mutex_);
    if (snapshot_.state == SessionState::kStopped) {
      return Result::kOk;
    }
    snapshot_.state = SessionState::kStopped;
    snapshot_.current_state = {};
  }
  backend_->Close();
  return Result::kOk;
}

InputCaptureSnapshot InputCapture::Snapshot() const {
  std::lock_guard lock(mutex_);
  return snapshot_;
}

void InputCapture::OnState(const protocol::GamepadStateV1& state) noexcept {
  const auto timestamp_us = static_cast<std::uint64_t>(
      std::chrono::duration_cast<std::chrono::microseconds>(
          std::chrono::steady_clock::now().time_since_epoch())
          .count());

  std::lock_guard lock(mutex_);
  if (snapshot_.state != SessionState::kRunning) {
    return;
  }
  snapshot_.current_state = state;
  snapshot_.timestamp_us = timestamp_us;
  snapshot_.observed_button_flags |= state.button_flags;
  snapshot_.left_trigger_max =
      std::max(snapshot_.left_trigger_max, state.left_trigger);
  snapshot_.right_trigger_max =
      std::max(snapshot_.right_trigger_max, state.right_trigger);

  if (!has_sample_) {
    snapshot_.left_stick_x_min = snapshot_.left_stick_x_max =
        state.left_stick_x;
    snapshot_.left_stick_y_min = snapshot_.left_stick_y_max =
        state.left_stick_y;
    snapshot_.right_stick_x_min = snapshot_.right_stick_x_max =
        state.right_stick_x;
    snapshot_.right_stick_y_min = snapshot_.right_stick_y_max =
        state.right_stick_y;
    has_sample_ = true;
  } else {
    snapshot_.left_stick_x_min =
        std::min(snapshot_.left_stick_x_min, state.left_stick_x);
    snapshot_.left_stick_x_max =
        std::max(snapshot_.left_stick_x_max, state.left_stick_x);
    snapshot_.left_stick_y_min =
        std::min(snapshot_.left_stick_y_min, state.left_stick_y);
    snapshot_.left_stick_y_max =
        std::max(snapshot_.left_stick_y_max, state.left_stick_y);
    snapshot_.right_stick_x_min =
        std::min(snapshot_.right_stick_x_min, state.right_stick_x);
    snapshot_.right_stick_x_max =
        std::max(snapshot_.right_stick_x_max, state.right_stick_x);
    snapshot_.right_stick_y_min =
        std::min(snapshot_.right_stick_y_min, state.right_stick_y);
    snapshot_.right_stick_y_max =
        std::max(snapshot_.right_stick_y_max, state.right_stick_y);
  }
  ++snapshot_.sample_count;
}

void InputCapture::OnDisconnected() noexcept {
  std::lock_guard lock(mutex_);
  if (snapshot_.state == SessionState::kRunning) {
    snapshot_.state = SessionState::kDisconnected;
    snapshot_.current_state = {};
  }
}

}  // namespace remote_controller
