// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#ifndef REMOTE_CONTROLLER_LOCAL_CONTROLLER_BRIDGE_H_
#define REMOTE_CONTROLLER_LOCAL_CONTROLLER_BRIDGE_H_

#include <cstdint>
#include <memory>
#include <mutex>
#include <string>

#include "backends/input_backend.h"
#include "backends/virtual_controller_backend.h"
#include "controller_protocol.h"
#include "session.h"

namespace remote_controller {

struct LocalControllerBridgeSnapshot {
  SessionState state{SessionState::kCreated};
  std::uint64_t sample_count{};
  std::uint64_t timestamp_us{};
  protocol::GamepadStateV1 current_state{};
  std::uint64_t rumble_count{};
  std::uint16_t low_frequency_motor{};
  std::uint16_t high_frequency_motor{};
};

class LocalControllerBridge final {
 public:
  LocalControllerBridge(
      std::unique_ptr<backends::InputBackend> input_backend,
      std::unique_ptr<backends::VirtualControllerBackend> virtual_backend,
      std::string device_id);
  ~LocalControllerBridge();

  LocalControllerBridge(const LocalControllerBridge&) = delete;
  LocalControllerBridge& operator=(const LocalControllerBridge&) = delete;

  Result Start();
  Result Stop();
  LocalControllerBridgeSnapshot Snapshot() const;

 private:
  void OnState(const protocol::GamepadStateV1& state) noexcept;
  void OnDisconnected() noexcept;
  void OnRumble(const backends::RumbleCommand& command) noexcept;

  std::unique_ptr<backends::InputBackend> input_backend_;
  std::unique_ptr<backends::VirtualControllerBackend> virtual_backend_;
  const std::string device_id_;
  mutable std::mutex mutex_;
  LocalControllerBridgeSnapshot snapshot_;
};

}  // namespace remote_controller

#endif  // REMOTE_CONTROLLER_LOCAL_CONTROLLER_BRIDGE_H_
