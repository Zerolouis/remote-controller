// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#include "lan_controller_session.h"

#include <utility>

namespace remote_controller {

LanControllerClient::LanControllerClient(
    std::unique_ptr<backends::InputBackend> input_backend,
    std::unique_ptr<backends::UdpLanTransportBackend> transport_backend,
    std::string device_id)
    : input_backend_(std::move(input_backend)),
      transport_backend_(std::move(transport_backend)),
      device_id_(std::move(device_id)) {}

LanControllerClient::~LanControllerClient() { Stop(); }

Result LanControllerClient::Start() {
  std::lock_guard lock(mutex_);
  if (state_ != SessionState::kCreated) {
    return Result::kInvalidState;
  }
  state_ = SessionState::kRunning;
  stop_requested_ = false;
  worker_ = std::thread(&LanControllerClient::StartWorker, this);
  return Result::kOk;
}

void LanControllerClient::StartWorker() noexcept {
  const bool transport_started = transport_backend_->StartClient(
      {}, [this](const backends::RumbleCommand& command) { OnRumble(command); },
      [this] { OnTransportDisconnected(); });
  if (!transport_started) {
    std::lock_guard lock(mutex_);
    if (!stop_requested_ && state_ == SessionState::kRunning) {
      state_ = SessionState::kFaulted;
    }
    condition_.notify_all();
    return;
  }

  bool input_opened = false;
  {
    std::lock_guard lifecycle_lock(input_lifecycle_mutex_);
    {
      std::lock_guard lock(mutex_);
      if (stop_requested_ || state_ != SessionState::kRunning) {
        condition_.notify_all();
        return;
      }
    }
    input_opened = input_backend_->Open(
        device_id_,
        [this](const protocol::GamepadStateV1& state) { OnInputState(state); },
        [this] { OnInputDisconnected(); });
  }
  if (!input_opened) {
    {
      std::lock_guard lock(mutex_);
      if (!stop_requested_ && state_ == SessionState::kRunning) {
        state_ = SessionState::kFaulted;
      }
    }
    transport_backend_->Stop();
    condition_.notify_all();
    return;
  }

  {
    std::unique_lock lock(mutex_);
    condition_.wait(lock, [this] {
      return stop_requested_ || state_ != SessionState::kRunning;
    });
  }
  CloseInput();
}

Result LanControllerClient::Stop() {
  bool send_neutral = false;
  {
    std::lock_guard lock(mutex_);
    if (state_ == SessionState::kStopped) {
      return Result::kOk;
    }
    send_neutral = state_ == SessionState::kRunning;
    state_ = SessionState::kStopped;
    stop_requested_ = true;
    current_state_ = {};
  }
  condition_.notify_all();
  CloseInput();

  if (send_neutral && transport_backend_->Snapshot().connected) {
    std::uint64_t sequence = 0;
    {
      std::lock_guard lock(mutex_);
      sequence = NextSequenceLocked();
      last_input_timestamp_us_ = TimestampUs();
    }
    static_cast<void>(transport_backend_->SendState(
        {}, sequence, last_input_timestamp_us_));
  }
  transport_backend_->Stop();
  if (worker_.joinable()) {
    worker_.join();
  }
  return Result::kOk;
}

LanSessionSnapshot LanControllerClient::Snapshot() const {
  const auto transport = transport_backend_->Snapshot();
  std::lock_guard lock(mutex_);
  return {
      state_,
      transport.connected,
      transport.sent_packet_count,
      transport.received_packet_count,
      transport.dropped_packet_count,
      0,
      latest_sequence_,
      last_input_timestamp_us_,
      rumble_count_,
      current_state_,
      low_frequency_motor_,
      high_frequency_motor_,
      transport.last_error,
      transport.peer_address,
      transport.error,
  };
}

void LanControllerClient::OnInputState(
    const protocol::GamepadStateV1& state) noexcept {
  std::uint64_t sequence = 0;
  const std::uint64_t timestamp_us = TimestampUs();
  {
    std::lock_guard lock(mutex_);
    if (state_ != SessionState::kRunning || stop_requested_) {
      return;
    }
    sequence = NextSequenceLocked();
  }
  if (!transport_backend_->SendState(state, sequence, timestamp_us)) {
    OnTransportDisconnected();
    return;
  }
  std::lock_guard lock(mutex_);
  if (state_ == SessionState::kRunning) {
    current_state_ = state;
    last_input_timestamp_us_ = timestamp_us;
  }
}

void LanControllerClient::OnInputDisconnected() noexcept {
  {
    std::lock_guard lock(mutex_);
    if (state_ != SessionState::kRunning) {
      return;
    }
    state_ = SessionState::kDisconnected;
    current_state_ = {};
  }
  condition_.notify_all();
}

void LanControllerClient::OnRumble(
    const backends::RumbleCommand& command) noexcept {
  {
    std::lock_guard lock(mutex_);
    if (state_ != SessionState::kRunning) {
      return;
    }
    low_frequency_motor_ = command.low_frequency_motor;
    high_frequency_motor_ = command.high_frequency_motor;
    ++rumble_count_;
  }
  static_cast<void>(input_backend_->SetRumble(command.low_frequency_motor,
                                              command.high_frequency_motor));
}

void LanControllerClient::OnTransportDisconnected() noexcept {
  {
    std::lock_guard lock(mutex_);
    if (state_ != SessionState::kRunning) {
      return;
    }
    state_ = SessionState::kDisconnected;
    current_state_ = {};
  }
  condition_.notify_all();
}

void LanControllerClient::CloseInput() noexcept {
  std::lock_guard lifecycle_lock(input_lifecycle_mutex_);
  input_backend_->Close();
}

std::uint64_t LanControllerClient::NextSequenceLocked() noexcept {
  return ++latest_sequence_;
}

std::uint64_t LanControllerClient::TimestampUs() noexcept {
  return static_cast<std::uint64_t>(
      std::chrono::duration_cast<std::chrono::microseconds>(
          std::chrono::steady_clock::now().time_since_epoch())
          .count());
}

LanControllerServer::LanControllerServer(
    std::unique_ptr<backends::UdpLanTransportBackend> transport_backend,
    std::unique_ptr<backends::VirtualControllerBackend> virtual_backend,
    const std::chrono::milliseconds input_timeout)
    : transport_backend_(std::move(transport_backend)),
      virtual_backend_(std::move(virtual_backend)),
      input_timeout_(input_timeout) {}

LanControllerServer::~LanControllerServer() { Stop(); }

Result LanControllerServer::Start() {
  {
    std::lock_guard lock(mutex_);
    if (state_ != SessionState::kCreated) {
      return Result::kInvalidState;
    }
  }
  if (!virtual_backend_->Create(
          [this](const backends::RumbleCommand& command) {
            OnRumble(command);
          })) {
    std::lock_guard lock(mutex_);
    state_ = SessionState::kFaulted;
    return Result::kBackendFailure;
  }
  {
    std::lock_guard lock(mutex_);
    state_ = SessionState::kRunning;
    stop_requested_ = false;
  }
  worker_ = std::thread(&LanControllerServer::StartWorker, this);
  return Result::kOk;
}

void LanControllerServer::StartWorker() noexcept {
  const bool transport_started = transport_backend_->StartServer(
      [this](const backends::StateFrame& frame) { OnState(frame); }, {},
      [this] { OnTransportDisconnected(); });
  if (!transport_started) {
    std::lock_guard lock(mutex_);
    if (!stop_requested_ && state_ == SessionState::kRunning) {
      state_ = SessionState::kFaulted;
      NeutralizeLocked();
    }
    condition_.notify_all();
    return;
  }

  std::unique_lock lock(mutex_);
  while (!stop_requested_ && state_ == SessionState::kRunning) {
    if (!watchdog_armed_) {
      condition_.wait(lock, [this] {
        return stop_requested_ || state_ != SessionState::kRunning ||
               watchdog_armed_;
      });
      continue;
    }
    const auto deadline = last_input_arrival_ + input_timeout_;
    if (condition_.wait_until(lock, deadline) == std::cv_status::timeout &&
        !stop_requested_ && state_ == SessionState::kRunning &&
        watchdog_armed_ && std::chrono::steady_clock::now() >= deadline) {
      NeutralizeLocked();
      watchdog_armed_ = false;
    }
  }
}

Result LanControllerServer::Stop() {
  {
    std::lock_guard lock(mutex_);
    if (state_ == SessionState::kStopped) {
      return Result::kOk;
    }
    if (state_ == SessionState::kRunning) {
      NeutralizeLocked();
    }
    state_ = SessionState::kStopped;
    stop_requested_ = true;
  }
  condition_.notify_all();
  transport_backend_->Stop();
  if (worker_.joinable()) {
    worker_.join();
  }
  virtual_backend_->Destroy();
  return Result::kOk;
}

LanSessionSnapshot LanControllerServer::Snapshot() const {
  const auto transport = transport_backend_->Snapshot();
  std::lock_guard lock(mutex_);
  return {
      state_,
      transport.connected,
      transport.sent_packet_count,
      transport.received_packet_count,
      transport.dropped_packet_count,
      neutralization_count_,
      latest_sequence_,
      last_input_timestamp_us_,
      rumble_count_,
      current_state_,
      low_frequency_motor_,
      high_frequency_motor_,
      transport.last_error,
      transport.peer_address,
      transport.error,
  };
}

void LanControllerServer::OnState(
    const backends::StateFrame& frame) noexcept {
  std::lock_guard lock(mutex_);
  if (state_ != SessionState::kRunning || stop_requested_ ||
      (received_state_count_ != 0 && frame.sequence <= latest_sequence_)) {
    return;
  }
  if (!virtual_backend_->SubmitState(frame.state)) {
    state_ = SessionState::kFaulted;
    NeutralizeLocked();
    condition_.notify_all();
    return;
  }
  current_state_ = frame.state;
  latest_sequence_ = frame.sequence;
  ++received_state_count_;
  last_input_timestamp_us_ = frame.timestamp_us;
  last_input_arrival_ = std::chrono::steady_clock::now();
  watchdog_armed_ = true;
  condition_.notify_all();
}

void LanControllerServer::OnRumble(
    const backends::RumbleCommand& command) noexcept {
  {
    std::lock_guard lock(mutex_);
    if (state_ != SessionState::kRunning) {
      return;
    }
    low_frequency_motor_ = command.low_frequency_motor;
    high_frequency_motor_ = command.high_frequency_motor;
    ++rumble_count_;
  }
  static_cast<void>(transport_backend_->SendRumble(command));
}

void LanControllerServer::OnTransportDisconnected() noexcept {
  {
    std::lock_guard lock(mutex_);
    if (state_ != SessionState::kRunning) {
      return;
    }
    state_ = SessionState::kDisconnected;
    NeutralizeLocked();
  }
  condition_.notify_all();
}

void LanControllerServer::NeutralizeLocked() noexcept {
  virtual_backend_->SubmitNeutralState();
  current_state_ = {};
  ++neutralization_count_;
  watchdog_armed_ = false;
}

}  // namespace remote_controller
