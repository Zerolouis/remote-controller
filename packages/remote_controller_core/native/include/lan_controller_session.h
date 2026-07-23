// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#ifndef REMOTE_CONTROLLER_LAN_CONTROLLER_SESSION_H_
#define REMOTE_CONTROLLER_LAN_CONTROLLER_SESSION_H_

#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>
#include <thread>

#include "backends/input_backend.h"
#include "backends/udp_lan_transport_backend.h"
#include "backends/virtual_controller_backend.h"
#include "session.h"

namespace remote_controller {

struct LanSessionSnapshot {
  SessionState state{SessionState::kCreated};
  bool connected{};
  std::uint64_t sent_packet_count{};
  std::uint64_t received_packet_count{};
  std::uint64_t dropped_packet_count{};
  std::uint64_t neutralization_count{};
  std::uint64_t latest_sequence{};
  std::uint64_t last_input_timestamp_us{};
  std::uint64_t rumble_count{};
  protocol::GamepadStateV1 current_state{};
  std::uint16_t low_frequency_motor{};
  std::uint16_t high_frequency_motor{};
  std::uint32_t last_error{};
  std::string peer_address;
  std::string error;
};

class LanControllerClient final {
 public:
  LanControllerClient(std::unique_ptr<backends::InputBackend> input_backend,
                      std::unique_ptr<backends::UdpLanTransportBackend>
                          transport_backend,
                      std::string device_id);
  ~LanControllerClient();

  LanControllerClient(const LanControllerClient&) = delete;
  LanControllerClient& operator=(const LanControllerClient&) = delete;

  Result Start();
  Result Stop();
  LanSessionSnapshot Snapshot() const;

 private:
  void StartWorker() noexcept;
  void OnInputState(const protocol::GamepadStateV1& state) noexcept;
  void OnInputDisconnected() noexcept;
  void OnRumble(const backends::RumbleCommand& command) noexcept;
  void OnTransportDisconnected() noexcept;
  void CloseInput() noexcept;
  std::uint64_t NextSequenceLocked() noexcept;
  static std::uint64_t TimestampUs() noexcept;

  std::unique_ptr<backends::InputBackend> input_backend_;
  std::unique_ptr<backends::UdpLanTransportBackend> transport_backend_;
  const std::string device_id_;
  mutable std::mutex mutex_;
  std::mutex input_lifecycle_mutex_;
  std::condition_variable condition_;
  std::thread worker_;
  SessionState state_{SessionState::kCreated};
  protocol::GamepadStateV1 current_state_{};
  std::uint64_t latest_sequence_{};
  std::uint64_t last_input_timestamp_us_{};
  std::uint64_t rumble_count_{};
  std::uint16_t low_frequency_motor_{};
  std::uint16_t high_frequency_motor_{};
  bool stop_requested_{};
};

class LanControllerServer final {
 public:
  LanControllerServer(
      std::unique_ptr<backends::UdpLanTransportBackend> transport_backend,
      std::unique_ptr<backends::VirtualControllerBackend> virtual_backend,
      std::chrono::milliseconds input_timeout);
  ~LanControllerServer();

  LanControllerServer(const LanControllerServer&) = delete;
  LanControllerServer& operator=(const LanControllerServer&) = delete;

  Result Start();
  Result Stop();
  LanSessionSnapshot Snapshot() const;

 private:
  void StartWorker() noexcept;
  void OnState(const backends::StateFrame& frame) noexcept;
  void OnRumble(const backends::RumbleCommand& command) noexcept;
  void OnTransportDisconnected() noexcept;
  void NeutralizeLocked() noexcept;

  std::unique_ptr<backends::UdpLanTransportBackend> transport_backend_;
  std::unique_ptr<backends::VirtualControllerBackend> virtual_backend_;
  const std::chrono::milliseconds input_timeout_;
  mutable std::mutex mutex_;
  std::condition_variable condition_;
  std::thread worker_;
  SessionState state_{SessionState::kCreated};
  protocol::GamepadStateV1 current_state_{};
  std::uint64_t latest_sequence_{};
  std::uint64_t received_state_count_{};
  std::uint64_t neutralization_count_{};
  std::uint64_t last_input_timestamp_us_{};
  std::uint64_t rumble_count_{};
  std::uint16_t low_frequency_motor_{};
  std::uint16_t high_frequency_motor_{};
  std::chrono::steady_clock::time_point last_input_arrival_{};
  bool watchdog_armed_{};
  bool stop_requested_{};
};

}  // namespace remote_controller

#endif  // REMOTE_CONTROLLER_LAN_CONTROLLER_SESSION_H_
