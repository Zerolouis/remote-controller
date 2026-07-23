// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#ifndef REMOTE_CONTROLLER_BACKENDS_MEMORY_VIRTUAL_CONTROLLER_BACKEND_H_
#define REMOTE_CONTROLLER_BACKENDS_MEMORY_VIRTUAL_CONTROLLER_BACKEND_H_

#include "backends/virtual_controller_backend.h"

namespace remote_controller::backends {

class MemoryVirtualControllerBackend final : public VirtualControllerBackend {
 public:
  bool Create(RumbleCallback callback) override;
  bool SubmitState(const protocol::GamepadStateV1& state) override;
  void SubmitNeutralState() noexcept override;
  void Destroy() noexcept override;

 private:
  RumbleCallback rumble_callback_;
  bool created_{false};
};

}  // namespace remote_controller::backends

#endif  // REMOTE_CONTROLLER_BACKENDS_MEMORY_VIRTUAL_CONTROLLER_BACKEND_H_
