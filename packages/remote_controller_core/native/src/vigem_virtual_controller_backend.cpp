// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#include "backends/vigem_virtual_controller_backend.h"

#include <utility>

namespace remote_controller::backends {
namespace {

std::string VigemErrorMessage(const VIGEM_ERROR result) {
  switch (result) {
    case VIGEM_ERROR_NONE:
      return {};
    case VIGEM_ERROR_BUS_NOT_FOUND:
      return "ViGEmBus driver was not found.";
    case VIGEM_ERROR_NO_FREE_SLOT:
      return "ViGEmBus has no free virtual controller slot.";
    case VIGEM_ERROR_INVALID_TARGET:
      return "ViGEmClient received an invalid target.";
    case VIGEM_ERROR_REMOVAL_FAILED:
      return "ViGEmBus failed to remove the virtual controller.";
    case VIGEM_ERROR_ALREADY_CONNECTED:
      return "The ViGEm target is already connected.";
    case VIGEM_ERROR_TARGET_UNINITIALIZED:
      return "The ViGEm target is not initialized.";
    case VIGEM_ERROR_TARGET_NOT_PLUGGED_IN:
      return "The ViGEm target is not plugged in.";
    case VIGEM_ERROR_BUS_VERSION_MISMATCH:
      return "ViGEmClient and ViGEmBus versions are incompatible.";
    case VIGEM_ERROR_BUS_ACCESS_FAILED:
      return "ViGEmBus was found but could not be opened.";
    case VIGEM_ERROR_CALLBACK_ALREADY_REGISTERED:
      return "A ViGEm rumble callback is already registered.";
    case VIGEM_ERROR_CALLBACK_NOT_FOUND:
      return "The ViGEm rumble callback was not found.";
    case VIGEM_ERROR_BUS_ALREADY_CONNECTED:
      return "The ViGEm client is already connected to the bus.";
    case VIGEM_ERROR_BUS_INVALID_HANDLE:
      return "ViGEmClient has an invalid bus handle.";
    case VIGEM_ERROR_XUSB_USERINDEX_OUT_OF_RANGE:
      return "The ViGEm XInput user index is out of range.";
    case VIGEM_ERROR_INVALID_PARAMETER:
      return "ViGEmClient received an invalid parameter.";
    case VIGEM_ERROR_NOT_SUPPORTED:
      return "The installed ViGEmBus does not support this operation.";
    case VIGEM_ERROR_WINAPI:
      return "A Windows API operation failed inside ViGEmClient.";
    case VIGEM_ERROR_TIMED_OUT:
      return "A ViGEmClient operation timed out.";
    case VIGEM_ERROR_IS_DISPOSING:
      return "The ViGEm target is being disposed.";
    default:
      return "ViGEmClient returned an unknown error.";
  }
}

std::uint8_t QuantizeTrigger(const std::uint16_t value) noexcept {
  return static_cast<std::uint8_t>(
      (static_cast<std::uint32_t>(value) * 255U + 32767U) / 65535U);
}

}  // namespace

XUSB_REPORT ToXusbReport(const protocol::GamepadStateV1& state) noexcept {
  XUSB_REPORT report{};
  const auto flags = state.button_flags;
  if ((flags & protocol::kDpadUp) != 0) {
    report.wButtons |= XUSB_GAMEPAD_DPAD_UP;
  }
  if ((flags & protocol::kDpadDown) != 0) {
    report.wButtons |= XUSB_GAMEPAD_DPAD_DOWN;
  }
  if ((flags & protocol::kDpadLeft) != 0) {
    report.wButtons |= XUSB_GAMEPAD_DPAD_LEFT;
  }
  if ((flags & protocol::kDpadRight) != 0) {
    report.wButtons |= XUSB_GAMEPAD_DPAD_RIGHT;
  }
  if ((flags & protocol::kStart) != 0) {
    report.wButtons |= XUSB_GAMEPAD_START;
  }
  if ((flags & protocol::kBack) != 0) {
    report.wButtons |= XUSB_GAMEPAD_BACK;
  }
  if ((flags & protocol::kLeftStick) != 0) {
    report.wButtons |= XUSB_GAMEPAD_LEFT_THUMB;
  }
  if ((flags & protocol::kRightStick) != 0) {
    report.wButtons |= XUSB_GAMEPAD_RIGHT_THUMB;
  }
  if ((flags & protocol::kLeftShoulder) != 0) {
    report.wButtons |= XUSB_GAMEPAD_LEFT_SHOULDER;
  }
  if ((flags & protocol::kRightShoulder) != 0) {
    report.wButtons |= XUSB_GAMEPAD_RIGHT_SHOULDER;
  }
  if ((flags & protocol::kGuide) != 0) {
    report.wButtons |= XUSB_GAMEPAD_GUIDE;
  }
  if ((flags & protocol::kA) != 0) {
    report.wButtons |= XUSB_GAMEPAD_A;
  }
  if ((flags & protocol::kB) != 0) {
    report.wButtons |= XUSB_GAMEPAD_B;
  }
  if ((flags & protocol::kX) != 0) {
    report.wButtons |= XUSB_GAMEPAD_X;
  }
  if ((flags & protocol::kY) != 0) {
    report.wButtons |= XUSB_GAMEPAD_Y;
  }
  report.bLeftTrigger = QuantizeTrigger(state.left_trigger);
  report.bRightTrigger = QuantizeTrigger(state.right_trigger);
  report.sThumbLX = state.left_stick_x;
  report.sThumbLY = state.left_stick_y;
  report.sThumbRX = state.right_stick_x;
  report.sThumbRY = state.right_stick_y;
  return report;
}

VigemVirtualControllerBackend::~VigemVirtualControllerBackend() { Destroy(); }

VigemRuntimeInfo VigemVirtualControllerBackend::Probe() {
  PVIGEM_CLIENT client = vigem_alloc();
  if (client == nullptr) {
    return {false, 0, "ViGEmClient could not allocate a driver client."};
  }
  const auto result = vigem_connect(client);
  if (VIGEM_SUCCESS(result)) {
    vigem_disconnect(client);
  }
  vigem_free(client);
  return {
      VIGEM_SUCCESS(result),
      static_cast<std::uint32_t>(result),
      VigemErrorMessage(result),
  };
}

bool VigemVirtualControllerBackend::Create(RumbleCallback callback) {
  {
    std::lock_guard lock(mutex_);
    if (created_) {
      return false;
    }
    last_result_code_ = 0;
    last_error_.clear();
  }

  PVIGEM_CLIENT client = vigem_alloc();
  if (client == nullptr) {
    std::lock_guard lock(mutex_);
    last_error_ = "ViGEmClient could not allocate a driver client.";
    return false;
  }

  auto result = vigem_connect(client);
  if (!VIGEM_SUCCESS(result)) {
    SetError(result);
    vigem_free(client);
    return false;
  }

  PVIGEM_TARGET target = vigem_target_x360_alloc();
  if (target == nullptr) {
    std::lock_guard lock(mutex_);
    last_error_ = "ViGEmClient could not allocate an Xbox 360 target.";
    vigem_disconnect(client);
    vigem_free(client);
    return false;
  }

  result = vigem_target_add(client, target);
  if (!VIGEM_SUCCESS(result)) {
    SetError(result);
    vigem_target_free(target);
    vigem_disconnect(client);
    vigem_free(client);
    return false;
  }

  result = vigem_target_x360_register_notification(
      client, target, &VigemVirtualControllerBackend::OnX360Notification,
      this);
  if (!VIGEM_SUCCESS(result)) {
    SetError(result);
    vigem_target_remove(client, target);
    vigem_target_free(target);
    vigem_disconnect(client);
    vigem_free(client);
    return false;
  }

  std::lock_guard lock(mutex_);
  client_ = client;
  target_ = target;
  rumble_callback_ = std::move(callback);
  notification_registered_ = true;
  created_ = true;
  return true;
}

bool VigemVirtualControllerBackend::SubmitState(
    const protocol::GamepadStateV1& state) {
  std::lock_guard lock(mutex_);
  if (!created_ || client_ == nullptr || target_ == nullptr) {
    return false;
  }
  const auto result = vigem_target_x360_update(client_, target_,
                                                ToXusbReport(state));
  if (!VIGEM_SUCCESS(result)) {
    last_result_code_ = static_cast<std::uint32_t>(result);
    last_error_ = VigemErrorMessage(result);
    return false;
  }
  return true;
}

void VigemVirtualControllerBackend::SubmitNeutralState() noexcept {
  static_cast<void>(SubmitState({}));
}

void VigemVirtualControllerBackend::Destroy() noexcept {
  PVIGEM_CLIENT client = nullptr;
  PVIGEM_TARGET target = nullptr;
  bool notification_registered = false;
  {
    std::lock_guard lock(mutex_);
    if (client_ == nullptr && target_ == nullptr) {
      created_ = false;
      rumble_callback_ = {};
      return;
    }
    created_ = false;
    client = client_;
    target = target_;
    notification_registered = notification_registered_;
    client_ = nullptr;
    target_ = nullptr;
    notification_registered_ = false;
    rumble_callback_ = {};
  }

  if (target != nullptr && notification_registered) {
    vigem_target_x360_unregister_notification(target);
  }
  if (client != nullptr && target != nullptr &&
      vigem_target_is_attached(target)) {
    static_cast<void>(vigem_target_x360_update(client, target, XUSB_REPORT{}));
    static_cast<void>(vigem_target_remove(client, target));
  }
  if (target != nullptr) {
    vigem_target_free(target);
  }
  if (client != nullptr) {
    vigem_disconnect(client);
    vigem_free(client);
  }
}

std::uint32_t VigemVirtualControllerBackend::last_result_code() const {
  std::lock_guard lock(mutex_);
  return last_result_code_;
}

std::string VigemVirtualControllerBackend::last_error() const {
  std::lock_guard lock(mutex_);
  return last_error_;
}

void CALLBACK VigemVirtualControllerBackend::OnX360Notification(
    PVIGEM_CLIENT, PVIGEM_TARGET, const UCHAR large_motor,
    const UCHAR small_motor, UCHAR, LPVOID user_data) {
  if (user_data != nullptr) {
    static_cast<VigemVirtualControllerBackend*>(user_data)
        ->HandleRumble(large_motor, small_motor);
  }
}

void VigemVirtualControllerBackend::HandleRumble(
    const std::uint8_t large_motor,
    const std::uint8_t small_motor) noexcept {
  RumbleCallback callback;
  {
    std::lock_guard lock(mutex_);
    if (!created_) {
      return;
    }
    callback = rumble_callback_;
  }
  if (callback) {
    callback({
        static_cast<std::uint16_t>(large_motor * 257U),
        static_cast<std::uint16_t>(small_motor * 257U),
    });
  }
}

void VigemVirtualControllerBackend::SetError(const VIGEM_ERROR result) {
  std::lock_guard lock(mutex_);
  last_result_code_ = static_cast<std::uint32_t>(result);
  last_error_ = VigemErrorMessage(result);
}

}  // namespace remote_controller::backends
