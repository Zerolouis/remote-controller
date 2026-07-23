// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#ifndef REMOTE_CONTROLLER_BACKENDS_TRANSPORT_BACKEND_H_
#define REMOTE_CONTROLLER_BACKENDS_TRANSPORT_BACKEND_H_

#include <cstdint>
#include <functional>
#include <span>

#include "controller_protocol.h"

namespace remote_controller::backends {

struct RumbleCommand {
  std::uint16_t low_frequency_motor{};
  std::uint16_t high_frequency_motor{};
};

struct StateFrame {
  protocol::GamepadStateV1 state{};
  std::uint64_t sequence{};
  std::uint64_t timestamp_us{};
};

class TransportBackend {
 public:
  using StateCallback = std::function<void(const StateFrame&)>;
  using RumbleCallback = std::function<void(const RumbleCommand&)>;
  using DisconnectCallback = std::function<void()>;

  virtual ~TransportBackend() = default;
  virtual bool StartClient(StateCallback state_callback, RumbleCallback rumble_callback,
                           DisconnectCallback disconnect_callback) = 0;
  virtual bool StartServer(StateCallback state_callback, RumbleCallback rumble_callback,
                           DisconnectCallback disconnect_callback) = 0;
  virtual bool SendState(const protocol::GamepadStateV1& state, std::uint64_t sequence,
                         std::uint64_t timestamp_us) = 0;
  virtual bool SendRumble(const RumbleCommand& command) = 0;
  virtual void Stop() noexcept = 0;
};

}  // namespace remote_controller::backends

#endif  // REMOTE_CONTROLLER_BACKENDS_TRANSPORT_BACKEND_H_
