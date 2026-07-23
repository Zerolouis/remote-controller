// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#include "backends/memory_virtual_controller_backend.h"

#include <utility>

namespace remote_controller::backends {

bool MemoryVirtualControllerBackend::Create(RumbleCallback callback) {
  if (created_) {
    return false;
  }
  rumble_callback_ = std::move(callback);
  created_ = true;
  return true;
}

bool MemoryVirtualControllerBackend::SubmitState(
    const protocol::GamepadStateV1& state) {
  static_cast<void>(state);
  return created_;
}

void MemoryVirtualControllerBackend::SubmitNeutralState() noexcept {}

void MemoryVirtualControllerBackend::Destroy() noexcept {
  created_ = false;
  rumble_callback_ = {};
}

}  // namespace remote_controller::backends
