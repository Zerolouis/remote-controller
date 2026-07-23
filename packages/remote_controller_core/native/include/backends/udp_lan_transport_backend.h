// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#ifndef REMOTE_CONTROLLER_BACKENDS_UDP_LAN_TRANSPORT_BACKEND_H_
#define REMOTE_CONTROLLER_BACKENDS_UDP_LAN_TRANSPORT_BACKEND_H_

#include <atomic>
#include <cstdint>
#include <mutex>
#include <string>
#include <thread>

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <WinSock2.h>
#include <WS2tcpip.h>

#include "backends/transport_backend.h"

namespace remote_controller::backends {

struct UdpLanTransportSnapshot {
  bool connected{};
  std::uint32_t session_id{};
  std::uint32_t last_error{};
  std::uint64_t sent_packet_count{};
  std::uint64_t received_packet_count{};
  std::uint64_t dropped_packet_count{};
  std::uint64_t control_message_count{};
  std::string peer_address;
  std::string error;
};

class UdpLanTransportBackend final : public TransportBackend {
 public:
  UdpLanTransportBackend(std::string server_address, std::uint16_t port);
  explicit UdpLanTransportBackend(std::uint16_t listen_port);
  ~UdpLanTransportBackend() override;

  UdpLanTransportBackend(const UdpLanTransportBackend&) = delete;
  UdpLanTransportBackend& operator=(const UdpLanTransportBackend&) = delete;

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

  UdpLanTransportSnapshot Snapshot() const;

 private:
  enum class Role { kClient, kServer };

  bool StartClientSockets();
  bool StartServerSockets();
  void ClientControlLoop() noexcept;
  void ServerControlLoop() noexcept;
  void ServerInputLoop() noexcept;
  void SignalDisconnected(std::uint32_t error,
                          std::string message) noexcept;
  void SetError(std::uint32_t error, std::string message) noexcept;
  void CloseSocket(SOCKET& socket) noexcept;

  const Role role_;
  const std::string server_address_;
  const std::uint16_t port_;

  mutable std::mutex mutex_;
  std::mutex control_send_mutex_;
  SOCKET listener_socket_{INVALID_SOCKET};
  SOCKET control_socket_{INVALID_SOCKET};
  SOCKET input_socket_{INVALID_SOCKET};
  sockaddr_in peer_input_address_{};
  StateCallback state_callback_;
  RumbleCallback rumble_callback_;
  DisconnectCallback disconnect_callback_;
  std::thread control_thread_;
  std::thread input_thread_;
  std::atomic_bool stop_requested_{false};
  std::atomic_bool disconnected_signaled_{false};
  std::atomic_uint32_t session_id_{};
  std::atomic_uint64_t sent_packet_count_{};
  std::atomic_uint64_t received_packet_count_{};
  std::atomic_uint64_t dropped_packet_count_{};
  std::atomic_uint64_t control_message_count_{};
  std::atomic_uint64_t highest_received_sequence_{};
  std::atomic_uint32_t pending_rumble_{};
  std::atomic_uint64_t rumble_generation_{};
  std::atomic_bool connected_{false};
  std::uint32_t last_error_{};
  std::string peer_address_;
  std::string error_;
};

}  // namespace remote_controller::backends

#endif  // REMOTE_CONTROLLER_BACKENDS_UDP_LAN_TRANSPORT_BACKEND_H_
