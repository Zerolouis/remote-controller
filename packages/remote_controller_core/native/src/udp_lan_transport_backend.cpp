// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#include "backends/udp_lan_transport_backend.h"

#include <algorithm>
#include <array>
#include <chrono>
#include <cstring>
#include <mutex>
#include <string>
#include <utility>

#include <bcrypt.h>

namespace remote_controller::backends {
namespace {

constexpr auto kConnectTimeout = std::chrono::seconds(3);
constexpr auto kControlPollPeriod = std::chrono::milliseconds(50);
constexpr auto kHeartbeatPeriod = std::chrono::seconds(1);
constexpr auto kHeartbeatTimeout = std::chrono::seconds(3);

bool EnsureWinsock() {
  static std::once_flag once;
  static bool available = false;
  std::call_once(once, [] {
    WSADATA data{};
    available = WSAStartup(MAKEWORD(2, 2), &data) == 0;
  });
  return available;
}

bool SetSocketTimeout(const SOCKET socket, const int option,
                      const DWORD milliseconds) {
  return setsockopt(socket, SOL_SOCKET, option,
                    reinterpret_cast<const char*>(&milliseconds),
                    sizeof(milliseconds)) == 0;
}

bool WaitForSocket(const SOCKET socket, const bool write,
                   const std::chrono::milliseconds timeout) {
  fd_set set;
  FD_ZERO(&set);
  FD_SET(socket, &set);
  timeval value{};
  value.tv_sec = static_cast<long>(timeout.count() / 1000);
  value.tv_usec = static_cast<long>((timeout.count() % 1000) * 1000);
  return select(0, write ? nullptr : &set, write ? &set : nullptr, nullptr,
                &value) > 0;
}

bool SendAll(const SOCKET socket, const void* data, const int length) {
  const auto* bytes = static_cast<const char*>(data);
  int sent = 0;
  while (sent < length) {
    const int result = send(socket, bytes + sent, length - sent, 0);
    if (result <= 0) {
      return false;
    }
    sent += result;
  }
  return true;
}

bool ReceiveAll(const SOCKET socket, void* data, const int length) {
  auto* bytes = static_cast<char*>(data);
  int received = 0;
  while (received < length) {
    const int result = recv(socket, bytes + received, length - received, 0);
    if (result <= 0) {
      return false;
    }
    received += result;
  }
  return true;
}

protocol::DiagnosticControlFrameV1 MakeControlFrame(
    const protocol::ControlMessageType type, const std::uint32_t session_id,
    const std::uint64_t sequence = 0,
    const RumbleCommand rumble = {}) {
  return {
      protocol::kControlMagic,
      protocol::kProtocolVersion,
      static_cast<std::uint8_t>(type),
      0,
      protocol::kControlFrameSize,
      0,
      session_id,
      sequence,
      rumble.low_frequency_motor,
      rumble.high_frequency_motor,
      0,
  };
}

bool ValidControlFrame(const protocol::DiagnosticControlFrameV1& frame,
                       const protocol::ControlMessageType expected,
                       const std::uint32_t session_id) {
  return frame.magic == protocol::kControlMagic &&
         frame.version == protocol::kProtocolVersion && frame.flags == 0 &&
         frame.frame_length == protocol::kControlFrameSize &&
         frame.message_type == static_cast<std::uint8_t>(expected) &&
         frame.session_id == session_id;
}

bool ResolveIpv4(const std::string& host, const std::uint16_t port,
                 sockaddr_in& address) {
  addrinfo hints{};
  hints.ai_family = AF_INET;
  hints.ai_socktype = SOCK_STREAM;
  hints.ai_protocol = IPPROTO_TCP;
  addrinfo* result = nullptr;
  const std::string service = std::to_string(port);
  if (getaddrinfo(host.c_str(), service.c_str(), &hints, &result) != 0 ||
      result == nullptr) {
    if (result != nullptr) {
      freeaddrinfo(result);
    }
    return false;
  }
  address = *reinterpret_cast<sockaddr_in*>(result->ai_addr);
  freeaddrinfo(result);
  return true;
}

bool ConnectWithTimeout(const SOCKET socket, const sockaddr_in& address) {
  u_long nonblocking = 1;
  if (ioctlsocket(socket, FIONBIO, &nonblocking) != 0) {
    return false;
  }
  const int result = connect(socket, reinterpret_cast<const sockaddr*>(&address),
                             sizeof(address));
  if (result == SOCKET_ERROR) {
    const int error = WSAGetLastError();
    if (error != WSAEWOULDBLOCK && error != WSAEINPROGRESS &&
        error != WSAEINVAL) {
      return false;
    }
    if (!WaitForSocket(socket, true,
                       std::chrono::duration_cast<std::chrono::milliseconds>(
                           kConnectTimeout))) {
      WSASetLastError(WSAETIMEDOUT);
      return false;
    }
    int socket_error = 0;
    int length = sizeof(socket_error);
    if (getsockopt(socket, SOL_SOCKET, SO_ERROR,
                   reinterpret_cast<char*>(&socket_error), &length) != 0 ||
        socket_error != 0) {
      WSASetLastError(socket_error == 0 ? WSAECONNREFUSED : socket_error);
      return false;
    }
  }
  nonblocking = 0;
  return ioctlsocket(socket, FIONBIO, &nonblocking) == 0;
}

std::uint32_t RandomSessionId() {
  std::uint32_t value = 0;
  if (BCryptGenRandom(nullptr, reinterpret_cast<PUCHAR>(&value), sizeof(value),
                      BCRYPT_USE_SYSTEM_PREFERRED_RNG) < 0) {
    value = static_cast<std::uint32_t>(
        std::chrono::steady_clock::now().time_since_epoch().count());
  }
  return value == 0 ? 1U : value;
}

std::string AddressText(const sockaddr_in& address) {
  std::array<char, INET_ADDRSTRLEN> buffer{};
  if (inet_ntop(AF_INET, &address.sin_addr, buffer.data(),
                static_cast<DWORD>(buffer.size())) == nullptr) {
    return {};
  }
  return buffer.data();
}

}  // namespace

UdpLanTransportBackend::UdpLanTransportBackend(std::string server_address,
                                               const std::uint16_t port)
    : role_(Role::kClient),
      server_address_(std::move(server_address)),
      port_(port) {}

UdpLanTransportBackend::UdpLanTransportBackend(
    const std::uint16_t listen_port)
    : role_(Role::kServer), port_(listen_port) {}

UdpLanTransportBackend::~UdpLanTransportBackend() { Stop(); }

bool UdpLanTransportBackend::StartClient(
    StateCallback state_callback, RumbleCallback rumble_callback,
    DisconnectCallback disconnect_callback) {
  if (role_ != Role::kClient || server_address_.empty() || port_ == 0 ||
      stop_requested_) {
    return false;
  }
  {
    std::lock_guard lock(mutex_);
    state_callback_ = std::move(state_callback);
    rumble_callback_ = std::move(rumble_callback);
    disconnect_callback_ = std::move(disconnect_callback);
  }
  if (!StartClientSockets()) {
    return false;
  }
  if (stop_requested_) {
    Stop();
    return false;
  }
  control_thread_ = std::thread(&UdpLanTransportBackend::ClientControlLoop,
                                this);
  return true;
}

bool UdpLanTransportBackend::StartServer(
    StateCallback state_callback, RumbleCallback rumble_callback,
    DisconnectCallback disconnect_callback) {
  if (role_ != Role::kServer || port_ == 0 || !state_callback ||
      stop_requested_) {
    return false;
  }
  {
    std::lock_guard lock(mutex_);
    state_callback_ = std::move(state_callback);
    rumble_callback_ = std::move(rumble_callback);
    disconnect_callback_ = std::move(disconnect_callback);
  }
  if (!StartServerSockets()) {
    return false;
  }
  if (stop_requested_) {
    Stop();
    return false;
  }
  control_thread_ = std::thread(&UdpLanTransportBackend::ServerControlLoop,
                                this);
  input_thread_ =
      std::thread(&UdpLanTransportBackend::ServerInputLoop, this);
  return true;
}

bool UdpLanTransportBackend::StartClientSockets() {
  if (!EnsureWinsock()) {
    SetError(WSASYSNOTREADY, "Winsock 2.2 initialization failed.");
    return false;
  }

  sockaddr_in server{};
  if (!ResolveIpv4(server_address_, port_, server)) {
    SetError(WSAHOST_NOT_FOUND, "The server address could not be resolved.");
    return false;
  }

  SOCKET control = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if (control == INVALID_SOCKET) {
    SetError(WSAGetLastError(), "The TCP control socket could not be created.");
    return false;
  }
  {
    std::lock_guard lock(mutex_);
    control_socket_ = control;
  }
  if (!ConnectWithTimeout(control, server)) {
    const auto error = static_cast<std::uint32_t>(WSAGetLastError());
    {
      std::lock_guard lock(mutex_);
      if (control_socket_ == control) {
        CloseSocket(control_socket_);
      }
    }
    SetError(error, "The TCP control connection failed.");
    return false;
  }
  SetSocketTimeout(control, SO_RCVTIMEO, 1000);
  SetSocketTimeout(control, SO_SNDTIMEO, 1000);

  SOCKET input = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
  if (input == INVALID_SOCKET) {
    const auto error = static_cast<std::uint32_t>(WSAGetLastError());
    {
      std::lock_guard lock(mutex_);
      CloseSocket(control_socket_);
    }
    SetError(error, "The UDP input socket could not be created.");
    return false;
  }
  u_long nonblocking = 1;
  ioctlsocket(input, FIONBIO, &nonblocking);
  {
    std::lock_guard lock(mutex_);
    input_socket_ = input;
  }

  const std::uint32_t session_id = RandomSessionId();
  const auto hello = MakeControlFrame(protocol::ControlMessageType::kHello,
                                      session_id);
  protocol::DiagnosticControlFrameV1 ack{};
  if (!SendAll(control, &hello, sizeof(hello)) ||
      !ReceiveAll(control, &ack, sizeof(ack)) ||
      !ValidControlFrame(ack, protocol::ControlMessageType::kHelloAck,
                         session_id)) {
    const auto error = static_cast<std::uint32_t>(WSAGetLastError());
    {
      std::lock_guard lock(mutex_);
      CloseSocket(input_socket_);
      CloseSocket(control_socket_);
    }
    SetError(error == 0 ? WSAEPROTONOSUPPORT : error,
             "The diagnostic control handshake failed.");
    return false;
  }
  if (stop_requested_) {
    std::lock_guard lock(mutex_);
    CloseSocket(input_socket_);
    CloseSocket(control_socket_);
    return false;
  }

  {
    std::lock_guard lock(mutex_);
    peer_input_address_ = server;
    peer_address_ = AddressText(server);
    connected_ = true;
    error_.clear();
    last_error_ = 0;
  }
  session_id_ = session_id;
  ++control_message_count_;
  return true;
}

bool UdpLanTransportBackend::StartServerSockets() {
  if (!EnsureWinsock()) {
    SetError(WSASYSNOTREADY, "Winsock 2.2 initialization failed.");
    return false;
  }

  SOCKET input = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
  SOCKET listener = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if (input == INVALID_SOCKET || listener == INVALID_SOCKET) {
    const auto error = static_cast<std::uint32_t>(WSAGetLastError());
    if (input != INVALID_SOCKET) {
      closesocket(input);
    }
    if (listener != INVALID_SOCKET) {
      closesocket(listener);
    }
    SetError(error, "The server sockets could not be created.");
    return false;
  }

  BOOL reuse = TRUE;
  setsockopt(listener, SOL_SOCKET, SO_REUSEADDR,
             reinterpret_cast<const char*>(&reuse), sizeof(reuse));
  sockaddr_in local{};
  local.sin_family = AF_INET;
  local.sin_addr.s_addr = htonl(INADDR_ANY);
  local.sin_port = htons(port_);
  if (bind(input, reinterpret_cast<const sockaddr*>(&local), sizeof(local)) !=
          0 ||
      bind(listener, reinterpret_cast<const sockaddr*>(&local),
           sizeof(local)) != 0 ||
      listen(listener, 1) != 0) {
    const auto error = static_cast<std::uint32_t>(WSAGetLastError());
    closesocket(input);
    closesocket(listener);
    SetError(error, "Port " + std::to_string(port_) +
                        " could not be bound for TCP and UDP.");
    return false;
  }
  SetSocketTimeout(input, SO_RCVTIMEO, 100);
  {
    std::lock_guard lock(mutex_);
    input_socket_ = input;
    listener_socket_ = listener;
  }

  sockaddr_in peer{};
  int peer_length = sizeof(peer);
  SOCKET control = INVALID_SOCKET;
  while (!stop_requested_) {
    if (!WaitForSocket(listener, false, std::chrono::milliseconds(100))) {
      continue;
    }
    control = accept(listener, reinterpret_cast<sockaddr*>(&peer),
                     &peer_length);
    if (control != INVALID_SOCKET) {
      break;
    }
    if (!stop_requested_) {
      SetError(WSAGetLastError(), "The TCP client could not be accepted.");
    }
    return false;
  }
  if (stop_requested_ || control == INVALID_SOCKET) {
    return false;
  }
  SetSocketTimeout(control, SO_RCVTIMEO, 1000);
  SetSocketTimeout(control, SO_SNDTIMEO, 1000);
  {
    std::lock_guard lock(mutex_);
    control_socket_ = control;
  }

  protocol::DiagnosticControlFrameV1 hello{};
  if (!ReceiveAll(control, &hello, sizeof(hello)) || hello.session_id == 0 ||
      !ValidControlFrame(hello, protocol::ControlMessageType::kHello,
                         hello.session_id)) {
    const auto error = static_cast<std::uint32_t>(WSAGetLastError());
    {
      std::lock_guard lock(mutex_);
      if (control_socket_ == control) {
        CloseSocket(control_socket_);
      }
    }
    SetError(error == 0 ? WSAEPROTONOSUPPORT : error,
             "The diagnostic client handshake was rejected.");
    return false;
  }
  const auto ack = MakeControlFrame(protocol::ControlMessageType::kHelloAck,
                                    hello.session_id);
  if (!SendAll(control, &ack, sizeof(ack))) {
    const auto error = static_cast<std::uint32_t>(WSAGetLastError());
    {
      std::lock_guard lock(mutex_);
      if (control_socket_ == control) {
        CloseSocket(control_socket_);
      }
    }
    SetError(error, "The diagnostic handshake response could not be sent.");
    return false;
  }
  if (stop_requested_) {
    std::lock_guard lock(mutex_);
    if (control_socket_ == control) {
      CloseSocket(control_socket_);
    }
    return false;
  }

  {
    std::lock_guard lock(mutex_);
    peer_input_address_ = peer;
    peer_address_ = AddressText(peer);
    connected_ = true;
    error_.clear();
    last_error_ = 0;
    CloseSocket(listener_socket_);
  }
  session_id_ = hello.session_id;
  ++control_message_count_;
  return true;
}

bool UdpLanTransportBackend::SendState(
    const protocol::GamepadStateV1& state, const std::uint64_t sequence,
    const std::uint64_t timestamp_us) {
  if (role_ != Role::kClient || !connected_) {
    return false;
  }
  protocol::InputDatagramV1 packet{};
  packet.header = {
      protocol::kInputMagic,
      protocol::kProtocolVersion,
      static_cast<std::uint8_t>(protocol::MessageType::kFullState),
      protocol::kInputFlagDiagnosticPlaintext,
      protocol::kInputDatagramSize,
      protocol::kInputHeaderSize,
      session_id_.load(),
      sequence,
      timestamp_us,
  };
  std::memcpy(packet.encrypted_state.data(), &state, sizeof(state));

  SOCKET input = INVALID_SOCKET;
  sockaddr_in peer{};
  {
    std::lock_guard lock(mutex_);
    input = input_socket_;
    peer = peer_input_address_;
  }
  if (input == INVALID_SOCKET) {
    return false;
  }
  const int sent = sendto(input, reinterpret_cast<const char*>(&packet),
                          sizeof(packet), 0,
                          reinterpret_cast<const sockaddr*>(&peer),
                          sizeof(peer));
  if (sent == sizeof(packet)) {
    ++sent_packet_count_;
    return true;
  }
  const int error = WSAGetLastError();
  if (error == WSAEWOULDBLOCK || error == WSAENOBUFS) {
    ++dropped_packet_count_;
    return true;
  }
  SignalDisconnected(static_cast<std::uint32_t>(error),
                     "The UDP input channel failed.");
  return false;
}

bool UdpLanTransportBackend::SendRumble(const RumbleCommand& command) {
  if (role_ != Role::kServer || !connected_) {
    return false;
  }
  pending_rumble_ =
      (static_cast<std::uint32_t>(command.high_frequency_motor) << 16U) |
      command.low_frequency_motor;
  ++rumble_generation_;
  return true;
}

void UdpLanTransportBackend::ClientControlLoop() noexcept {
  SOCKET control = INVALID_SOCKET;
  {
    std::lock_guard lock(mutex_);
    control = control_socket_;
  }
  auto next_heartbeat = std::chrono::steady_clock::now();
  std::uint64_t heartbeat_sequence = 0;
  while (!stop_requested_ && connected_) {
    const auto now = std::chrono::steady_clock::now();
    if (now >= next_heartbeat) {
      const auto heartbeat = MakeControlFrame(
          protocol::ControlMessageType::kHeartbeat, session_id_.load(),
          ++heartbeat_sequence);
      bool sent = false;
      {
        std::lock_guard send_lock(control_send_mutex_);
        sent = SendAll(control, &heartbeat, sizeof(heartbeat));
      }
      if (!sent) {
        SignalDisconnected(WSAGetLastError(),
                           "The TCP heartbeat could not be sent.");
        break;
      }
      ++control_message_count_;
      next_heartbeat = now + kHeartbeatPeriod;
    }

    if (!WaitForSocket(control, false, kControlPollPeriod)) {
      continue;
    }
    protocol::DiagnosticControlFrameV1 frame{};
    if (!ReceiveAll(control, &frame, sizeof(frame))) {
      SignalDisconnected(WSAGetLastError(),
                         "The TCP control channel was closed.");
      break;
    }
    ++control_message_count_;
    if (ValidControlFrame(frame, protocol::ControlMessageType::kRumble,
                          session_id_.load())) {
      RumbleCallback callback;
      {
        std::lock_guard lock(mutex_);
        callback = rumble_callback_;
      }
      if (callback) {
        callback({frame.low_frequency_motor, frame.high_frequency_motor});
      }
    } else if (ValidControlFrame(frame, protocol::ControlMessageType::kStop,
                                 session_id_.load())) {
      SignalDisconnected(0, "The server stopped the diagnostic session.");
      break;
    } else {
      SignalDisconnected(WSAEPROTONOSUPPORT,
                         "An invalid diagnostic control frame was received.");
      break;
    }
  }
}

void UdpLanTransportBackend::ServerControlLoop() noexcept {
  SOCKET control = INVALID_SOCKET;
  {
    std::lock_guard lock(mutex_);
    control = control_socket_;
  }
  auto last_heartbeat = std::chrono::steady_clock::now();
  std::uint64_t applied_rumble_generation = 0;
  while (!stop_requested_ && connected_) {
    const auto generation = rumble_generation_.load();
    if (generation != applied_rumble_generation) {
      const auto packed = pending_rumble_.load();
      const auto frame = MakeControlFrame(
          protocol::ControlMessageType::kRumble, session_id_.load(), generation,
          {static_cast<std::uint16_t>(packed & 0xFFFFU),
           static_cast<std::uint16_t>(packed >> 16U)});
      bool sent = false;
      {
        std::lock_guard send_lock(control_send_mutex_);
        sent = SendAll(control, &frame, sizeof(frame));
      }
      if (!sent) {
        SignalDisconnected(WSAGetLastError(),
                           "The rumble control message could not be sent.");
        break;
      }
      ++control_message_count_;
      applied_rumble_generation = generation;
    }

    if (std::chrono::steady_clock::now() - last_heartbeat >
        kHeartbeatTimeout) {
      SignalDisconnected(WSAETIMEDOUT,
                         "The client heartbeat timed out.");
      break;
    }
    if (!WaitForSocket(control, false, kControlPollPeriod)) {
      continue;
    }
    protocol::DiagnosticControlFrameV1 frame{};
    if (!ReceiveAll(control, &frame, sizeof(frame))) {
      SignalDisconnected(WSAGetLastError(),
                         "The TCP control channel was closed.");
      break;
    }
    ++control_message_count_;
    if (ValidControlFrame(frame, protocol::ControlMessageType::kHeartbeat,
                          session_id_.load())) {
      last_heartbeat = std::chrono::steady_clock::now();
    } else if (ValidControlFrame(frame, protocol::ControlMessageType::kStop,
                                 session_id_.load())) {
      SignalDisconnected(0, "The client stopped the diagnostic session.");
      break;
    } else {
      SignalDisconnected(WSAEPROTONOSUPPORT,
                         "An invalid diagnostic control frame was received.");
      break;
    }
  }
}

void UdpLanTransportBackend::ServerInputLoop() noexcept {
  SOCKET input = INVALID_SOCKET;
  sockaddr_in expected_peer{};
  {
    std::lock_guard lock(mutex_);
    input = input_socket_;
    expected_peer = peer_input_address_;
  }
  while (!stop_requested_ && connected_) {
    protocol::InputDatagramV1 packet{};
    sockaddr_in source{};
    int source_length = sizeof(source);
    const int received = recvfrom(
        input, reinterpret_cast<char*>(&packet), sizeof(packet), 0,
        reinterpret_cast<sockaddr*>(&source), &source_length);
    if (received == SOCKET_ERROR) {
      const int error = WSAGetLastError();
      if (error == WSAETIMEDOUT || error == WSAEWOULDBLOCK) {
        continue;
      }
      if (!stop_requested_) {
        SignalDisconnected(static_cast<std::uint32_t>(error),
                           "The UDP input receiver failed.");
      }
      break;
    }

    const bool valid_header =
        received == sizeof(packet) &&
        source.sin_addr.s_addr == expected_peer.sin_addr.s_addr &&
        packet.header.magic == protocol::kInputMagic &&
        packet.header.version == protocol::kProtocolVersion &&
        packet.header.message_type ==
            static_cast<std::uint8_t>(protocol::MessageType::kFullState) &&
        packet.header.flags == protocol::kInputFlagDiagnosticPlaintext &&
        packet.header.packet_length == protocol::kInputDatagramSize &&
        packet.header.header_length == protocol::kInputHeaderSize &&
        packet.header.session_id == session_id_.load() &&
        std::all_of(packet.authentication_tag.begin(),
                    packet.authentication_tag.end(),
                    [](const std::uint8_t value) { return value == 0; });
    const auto highest = highest_received_sequence_.load();
    if (!valid_header || packet.header.sequence <= highest) {
      ++dropped_packet_count_;
      continue;
    }
    highest_received_sequence_ = packet.header.sequence;

    StateCallback callback;
    {
      std::lock_guard lock(mutex_);
      callback = state_callback_;
    }
    if (callback) {
      protocol::GamepadStateV1 state{};
      std::memcpy(&state, packet.encrypted_state.data(), sizeof(state));
      callback({state, packet.header.sequence, packet.header.timestamp_us});
      ++received_packet_count_;
    }
  }
}

void UdpLanTransportBackend::Stop() noexcept {
  const bool already_stopping = stop_requested_.exchange(true);
  if (!already_stopping && connected_) {
    const auto frame = MakeControlFrame(protocol::ControlMessageType::kStop,
                                        session_id_.load());
    std::lock_guard send_lock(control_send_mutex_);
    SOCKET control = INVALID_SOCKET;
    {
      std::lock_guard lock(mutex_);
      control = control_socket_;
    }
    if (control != INVALID_SOCKET) {
      SendAll(control, &frame, sizeof(frame));
    }
  }
  {
    std::lock_guard lock(mutex_);
    connected_ = false;
    CloseSocket(listener_socket_);
    CloseSocket(control_socket_);
    CloseSocket(input_socket_);
  }
  if (control_thread_.joinable()) {
    control_thread_.join();
  }
  if (input_thread_.joinable()) {
    input_thread_.join();
  }
}

UdpLanTransportSnapshot UdpLanTransportBackend::Snapshot() const {
  std::lock_guard lock(mutex_);
  return {
      connected_.load(),
      session_id_.load(),
      last_error_,
      sent_packet_count_.load(),
      received_packet_count_.load(),
      dropped_packet_count_.load(),
      control_message_count_.load(),
      peer_address_,
      error_,
  };
}

void UdpLanTransportBackend::SignalDisconnected(
    const std::uint32_t error, std::string message) noexcept {
  if (disconnected_signaled_.exchange(true)) {
    return;
  }
  DisconnectCallback callback;
  {
    std::lock_guard lock(mutex_);
    connected_ = false;
    last_error_ = error;
    error_ = std::move(message);
    callback = disconnect_callback_;
  }
  if (!stop_requested_ && callback) {
    callback();
  }
}

void UdpLanTransportBackend::SetError(const std::uint32_t error,
                                      std::string message) noexcept {
  std::lock_guard lock(mutex_);
  connected_ = false;
  last_error_ = error;
  error_ = std::move(message);
}

void UdpLanTransportBackend::CloseSocket(SOCKET& socket) noexcept {
  if (socket == INVALID_SOCKET) {
    return;
  }
  shutdown(socket, SD_BOTH);
  closesocket(socket);
  socket = INVALID_SOCKET;
}

}  // namespace remote_controller::backends
