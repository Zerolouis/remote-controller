// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#ifndef REMOTE_CONTROLLER_BACKENDS_INPUT_BACKEND_H_
#define REMOTE_CONTROLLER_BACKENDS_INPUT_BACKEND_H_

#include <cstdint>
#include <functional>
#include <string>
#include <vector>

#include "controller_protocol.h"

namespace remote_controller::backends {

struct InputDeviceInfo {
  std::string id;
  std::string display_name;
  std::string device_path;
  std::string guid;
  std::uint16_t vendor_id{};
  std::uint16_t product_id{};
  std::uint16_t product_version{};
  std::uint32_t controller_type{};
  std::int32_t connection_state{};
  std::uint32_t capabilities{};
  std::uint32_t supported_buttons{};
  std::uint32_t flags{};
};

enum InputCapability : std::uint32_t {
  kAnalogTriggers = 1U << 0,
  kRumble = 1U << 1,
  kTriggerRumble = 1U << 2,
};

enum InputDeviceFlag : std::uint32_t {
  kRogAllyX = 1U << 0,
};

class InputBackend {
 public:
  using StateCallback = std::function<void(const protocol::GamepadStateV1&)>;
  using DisconnectCallback = std::function<void()>;

  virtual ~InputBackend() = default;
  virtual std::vector<InputDeviceInfo> EnumerateDevices() = 0;
  virtual bool Open(const std::string& device_id, StateCallback state_callback,
                    DisconnectCallback disconnect_callback) = 0;
  virtual void Close() noexcept = 0;
};

}  // namespace remote_controller::backends

#endif  // REMOTE_CONTROLLER_BACKENDS_INPUT_BACKEND_H_
