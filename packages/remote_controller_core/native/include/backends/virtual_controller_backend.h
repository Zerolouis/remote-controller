// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#ifndef REMOTE_CONTROLLER_BACKENDS_VIRTUAL_CONTROLLER_BACKEND_H_
#define REMOTE_CONTROLLER_BACKENDS_VIRTUAL_CONTROLLER_BACKEND_H_

#include <functional>

#include "backends/transport_backend.h"
#include "controller_protocol.h"

namespace remote_controller::backends {

class VirtualControllerBackend {
 public:
  using RumbleCallback = std::function<void(const RumbleCommand&)>;

  virtual ~VirtualControllerBackend() = default;
  virtual bool Create(RumbleCallback callback) = 0;
  virtual bool SubmitState(const protocol::GamepadStateV1& state) = 0;
  virtual void SubmitNeutralState() noexcept = 0;
  virtual void Destroy() noexcept = 0;
};

}  // namespace remote_controller::backends

#endif  // REMOTE_CONTROLLER_BACKENDS_VIRTUAL_CONTROLLER_BACKEND_H_
