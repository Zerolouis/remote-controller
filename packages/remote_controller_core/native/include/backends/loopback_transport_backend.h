// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#ifndef REMOTE_CONTROLLER_BACKENDS_LOOPBACK_TRANSPORT_BACKEND_H_
#define REMOTE_CONTROLLER_BACKENDS_LOOPBACK_TRANSPORT_BACKEND_H_

#include <cstddef>
#include <condition_variable>
#include <deque>
#include <mutex>
#include <thread>

#include "backends/transport_backend.h"

namespace remote_controller::backends {

class LoopbackTransportBackend final : public TransportBackend {
 public:
  LoopbackTransportBackend() = default;
  ~LoopbackTransportBackend() override;

  bool StartClient(StateCallback state_callback,
                   RumbleCallback rumble_callback,
                   DisconnectCallback disconnect_callback) override;
  bool StartServer(StateCallback state_callback,
                   RumbleCallback rumble_callback,
                   DisconnectCallback disconnect_callback) override;
  bool SendState(const protocol::GamepadStateV1& state,
                 std::uint64_t sequence,
                 std::uint64_t timestamp_us) override;
  bool SendRumble(const RumbleCommand& command) override;
  void Stop() noexcept override;

  void SimulateDisconnect() noexcept;

 private:
  bool Start(StateCallback state_callback, RumbleCallback rumble_callback,
             DisconnectCallback disconnect_callback);
  void WorkerLoop() noexcept;
  void Shutdown(bool notify_disconnect) noexcept;

  std::mutex mutex_;
  std::condition_variable condition_;
  static constexpr std::size_t kMaximumQueuedFrames = 64;

  std::deque<StateFrame> pending_states_;
  StateCallback state_callback_;
  RumbleCallback rumble_callback_;
  DisconnectCallback disconnect_callback_;
  std::thread worker_;
  bool accepting_{false};
  bool stop_requested_{false};
};

}  // namespace remote_controller::backends

#endif  // REMOTE_CONTROLLER_BACKENDS_LOOPBACK_TRANSPORT_BACKEND_H_
