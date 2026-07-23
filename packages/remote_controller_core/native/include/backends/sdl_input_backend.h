// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#ifndef REMOTE_CONTROLLER_BACKENDS_SDL_INPUT_BACKEND_H_
#define REMOTE_CONTROLLER_BACKENDS_SDL_INPUT_BACKEND_H_

#include <atomic>
#include <mutex>
#include <string>
#include <thread>

#include "backends/input_backend.h"

struct SDL_Gamepad;

namespace remote_controller::backends {

struct SdlRuntimeInfo {
  bool available{};
  std::uint32_t version{};
  std::string revision;
  std::string error;
};

class SdlInputBackend final : public InputBackend {
 public:
  SdlInputBackend() = default;
  ~SdlInputBackend() override;

  static SdlRuntimeInfo GetRuntimeInfo();

  std::vector<InputDeviceInfo> EnumerateDevices() override;
  bool Open(const std::string& device_id, StateCallback state_callback,
            DisconnectCallback disconnect_callback) override;
  bool SetRumble(std::uint16_t low_frequency_motor,
                 std::uint16_t high_frequency_motor) override;
  void Close() noexcept override;

 private:
  void PollLoop() noexcept;

  std::mutex mutex_;
  SDL_Gamepad* gamepad_{nullptr};
  StateCallback state_callback_;
  DisconnectCallback disconnect_callback_;
  std::thread poll_thread_;
  std::atomic_bool stop_requested_{false};
  std::atomic_uint32_t pending_rumble_{};
  std::atomic_uint64_t rumble_generation_{};
};

}  // namespace remote_controller::backends

#endif  // REMOTE_CONTROLLER_BACKENDS_SDL_INPUT_BACKEND_H_
