// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#ifndef REMOTE_CONTROLLER_SESSION_H_
#define REMOTE_CONTROLLER_SESSION_H_

#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <memory>
#include <mutex>
#include <thread>

#include "backends/loopback_transport_backend.h"
#include "backends/memory_virtual_controller_backend.h"
#include "controller_protocol.h"

namespace remote_controller {

enum class Result : std::int32_t {
  kOk = 0,
  kInvalidArgument = 1,
  kInvalidState = 2,
  kStaleSequence = 3,
  kBackendFailure = 4,
};

enum class SessionState : std::uint32_t {
  kCreated = 0,
  kRunning = 1,
  kStopped = 2,
  kDisconnected = 3,
  kFaulted = 4,
};

struct SessionSnapshot {
  SessionState state{SessionState::kCreated};
  std::uint64_t latest_sequence{};
  std::uint64_t accepted_state_count{};
  std::uint64_t neutralization_count{};
  std::uint64_t last_input_timestamp_us{};
  protocol::GamepadStateV1 output_state{};
};

class Session final {
 public:
  explicit Session(std::chrono::milliseconds input_timeout);
  ~Session();

  Session(const Session&) = delete;
  Session& operator=(const Session&) = delete;

  Result Start();
  Result SubmitState(const protocol::GamepadStateV1& state,
                     std::uint64_t sequence,
                     std::uint64_t timestamp_us);
  SessionSnapshot Snapshot() const;
  Result SimulateDisconnect();
  Result Stop();

 private:
  void OnStateFrame(const backends::StateFrame& frame) noexcept;
  void OnDisconnected() noexcept;
  void WatchdogLoop() noexcept;
  void NeutralizeLocked() noexcept;
  void JoinWatchdog() noexcept;

  const std::chrono::milliseconds input_timeout_;
  std::unique_ptr<backends::LoopbackTransportBackend> transport_;
  std::unique_ptr<backends::MemoryVirtualControllerBackend>
      virtual_controller_;

  mutable std::mutex mutex_;
  std::condition_variable watchdog_condition_;
  std::thread watchdog_thread_;
  SessionState state_{SessionState::kCreated};
  protocol::GamepadStateV1 output_state_{};
  std::uint64_t highest_submitted_sequence_{};
  std::uint64_t latest_sequence_{};
  std::uint64_t accepted_state_count_{};
  std::uint64_t neutralization_count_{};
  std::uint64_t last_input_timestamp_us_{};
  std::chrono::steady_clock::time_point last_input_arrival_{};
  bool has_submitted_sequence_{false};
  bool watchdog_armed_{false};
  bool watchdog_exit_{false};
};

}  // namespace remote_controller

#endif  // REMOTE_CONTROLLER_SESSION_H_
