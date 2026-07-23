// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#ifndef REMOTE_CONTROLLER_BACKENDS_VIGEM_VIRTUAL_CONTROLLER_BACKEND_H_
#define REMOTE_CONTROLLER_BACKENDS_VIGEM_VIRTUAL_CONTROLLER_BACKEND_H_

#include <cstdint>
#include <mutex>
#include <string>

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <Windows.h>

#include <ViGEm/Client.h>

#include "backends/virtual_controller_backend.h"

namespace remote_controller::backends {

struct VigemRuntimeInfo {
  bool available{};
  std::uint32_t result_code{};
  std::string error;
};

XUSB_REPORT ToXusbReport(const protocol::GamepadStateV1& state) noexcept;

class VigemVirtualControllerBackend final : public VirtualControllerBackend {
 public:
  VigemVirtualControllerBackend() = default;
  ~VigemVirtualControllerBackend() override;

  static VigemRuntimeInfo Probe();

  bool Create(RumbleCallback callback) override;
  bool SubmitState(const protocol::GamepadStateV1& state) override;
  void SubmitNeutralState() noexcept override;
  void Destroy() noexcept override;

  std::uint32_t last_result_code() const;
  std::string last_error() const;

 private:
  static void CALLBACK OnX360Notification(PVIGEM_CLIENT client,
                                          PVIGEM_TARGET target,
                                          UCHAR large_motor,
                                          UCHAR small_motor,
                                          UCHAR led_number,
                                          LPVOID user_data);
  void HandleRumble(std::uint8_t large_motor,
                    std::uint8_t small_motor) noexcept;
  void SetError(VIGEM_ERROR result);

  mutable std::mutex mutex_;
  PVIGEM_CLIENT client_{nullptr};
  PVIGEM_TARGET target_{nullptr};
  RumbleCallback rumble_callback_;
  std::uint32_t last_result_code_{};
  std::string last_error_;
  bool notification_registered_{false};
  bool created_{false};
};

}  // namespace remote_controller::backends

#endif  // REMOTE_CONTROLLER_BACKENDS_VIGEM_VIRTUAL_CONTROLLER_BACKEND_H_
