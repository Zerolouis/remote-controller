// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#ifndef REMOTE_CONTROLLER_INPUT_CAPTURE_H_
#define REMOTE_CONTROLLER_INPUT_CAPTURE_H_

#include <cstdint>
#include <memory>
#include <mutex>
#include <string>

#include "backends/input_backend.h"
#include "controller_protocol.h"
#include "session.h"

namespace remote_controller {

struct InputCaptureSnapshot {
  SessionState state{SessionState::kCreated};
  std::uint64_t sample_count{};
  std::uint64_t timestamp_us{};
  protocol::GamepadStateV1 current_state{};
  std::uint32_t observed_button_flags{};
  std::uint16_t left_trigger_max{};
  std::uint16_t right_trigger_max{};
  std::int16_t left_stick_x_min{};
  std::int16_t left_stick_x_max{};
  std::int16_t left_stick_y_min{};
  std::int16_t left_stick_y_max{};
  std::int16_t right_stick_x_min{};
  std::int16_t right_stick_x_max{};
  std::int16_t right_stick_y_min{};
  std::int16_t right_stick_y_max{};
};

class InputCapture final {
 public:
  InputCapture(std::unique_ptr<backends::InputBackend> backend,
               std::string device_id);
  ~InputCapture();

  InputCapture(const InputCapture&) = delete;
  InputCapture& operator=(const InputCapture&) = delete;

  Result Start();
  Result Stop();
  InputCaptureSnapshot Snapshot() const;

 private:
  void OnState(const protocol::GamepadStateV1& state) noexcept;
  void OnDisconnected() noexcept;

  std::unique_ptr<backends::InputBackend> backend_;
  const std::string device_id_;
  mutable std::mutex mutex_;
  InputCaptureSnapshot snapshot_;
  bool has_sample_{false};
};

}  // namespace remote_controller

#endif  // REMOTE_CONTROLLER_INPUT_CAPTURE_H_
