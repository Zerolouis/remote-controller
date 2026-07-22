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
  std::uint16_t vendor_id{};
  std::uint16_t product_id{};
  std::uint32_t capabilities{};
};

class InputBackend {
 public:
  using StateCallback = std::function<void(const protocol::GamepadStateV1&)>;

  virtual ~InputBackend() = default;
  virtual std::vector<InputDeviceInfo> EnumerateDevices() = 0;
  virtual bool Open(const std::string& device_id, StateCallback callback) = 0;
  virtual void Close() noexcept = 0;
};

}  // namespace remote_controller::backends

#endif  // REMOTE_CONTROLLER_BACKENDS_INPUT_BACKEND_H_
