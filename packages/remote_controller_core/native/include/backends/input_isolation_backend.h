// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#ifndef REMOTE_CONTROLLER_BACKENDS_INPUT_ISOLATION_BACKEND_H_
#define REMOTE_CONTROLLER_BACKENDS_INPUT_ISOLATION_BACKEND_H_

#include <string>

namespace remote_controller::backends {

class InputIsolationBackend {
 public:
  virtual ~InputIsolationBackend() = default;
  virtual bool IsAvailable() const = 0;
  virtual bool BeginExclusiveSession(const std::string& device_instance_path) = 0;
  virtual void EndExclusiveSession() noexcept = 0;
};

}  // namespace remote_controller::backends

#endif  // REMOTE_CONTROLLER_BACKENDS_INPUT_ISOLATION_BACKEND_H_
