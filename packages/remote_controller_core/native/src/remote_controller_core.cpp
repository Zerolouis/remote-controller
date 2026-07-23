// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#include "remote_controller_core.h"

#include <algorithm>
#include <chrono>
#include <cstring>
#include <memory>
#include <new>
#include <string_view>

#include "backends/sdl_input_backend.h"
#include "controller_protocol.h"
#include "input_capture.h"
#include "session.h"

namespace {

constexpr std::uint32_t kAbiVersion = 1;
constexpr char kBuildInfo[] =
    "remote-controller-core/0.3.0; abi=1; protocol=1; "
    "backends=sdl3,loopback,memory-virtual; watchdog=100ms-default";

remote_controller::protocol::GamepadStateV1 ToNativeState(
    const rc_gamepad_state_v1& state) {
  return {
      state.button_flags, state.left_trigger, state.right_trigger,
      state.left_stick_x, state.left_stick_y, state.right_stick_x,
      state.right_stick_y,
  };
}

rc_gamepad_state_v1 ToAbiState(
    const remote_controller::protocol::GamepadStateV1& state) {
  return {
      state.button_flags, state.left_trigger, state.right_trigger,
      state.left_stick_x, state.left_stick_y, state.right_stick_x,
      state.right_stick_y,
  };
}

rc_result ToAbiResult(const remote_controller::Result result) {
  return static_cast<rc_result>(result);
}

template <std::size_t Size>
void CopyUtf8(char (&destination)[Size], const std::string_view source) {
  static_assert(Size > 0);
  const auto length = std::min(source.size(), Size - 1);
  std::memcpy(destination, source.data(), length);
  destination[length] = '\0';
}

}  // namespace

struct rc_session {
  explicit rc_session(const std::chrono::milliseconds input_timeout)
      : implementation(input_timeout) {}

  remote_controller::Session implementation;
};

struct rc_input_capture {
  explicit rc_input_capture(const std::uint32_t instance_id)
      : implementation(
            std::make_unique<
                remote_controller::backends::SdlInputBackend>(),
            std::to_string(instance_id)) {}

  remote_controller::InputCapture implementation;
};

static_assert(sizeof(rc_gamepad_state_v1) ==
              sizeof(remote_controller::protocol::GamepadStateV1));
static_assert(sizeof(rc_session_snapshot_v1) == 56);
static_assert(sizeof(rc_sdl_runtime_info_v1) == 336);
static_assert(sizeof(rc_input_device_info_v1) == 712);
static_assert(sizeof(rc_input_capture_snapshot_v1) == 64);

extern "C" RC_API std::uint32_t rc_get_abi_version(void) { return kAbiVersion; }

extern "C" RC_API const char* rc_get_build_info(void) { return kBuildInfo; }

extern "C" RC_API rc_result rc_sdl_get_runtime_info(
    rc_sdl_runtime_info_v1* out_runtime_info) {
  if (out_runtime_info == nullptr ||
      out_runtime_info->struct_size != sizeof(rc_sdl_runtime_info_v1)) {
    return RC_RESULT_INVALID_ARGUMENT;
  }
  const auto struct_size = out_runtime_info->struct_size;
  *out_runtime_info = {};
  out_runtime_info->struct_size = struct_size;

  const auto runtime =
      remote_controller::backends::SdlInputBackend::GetRuntimeInfo();
  out_runtime_info->available = runtime.available ? 1U : 0U;
  out_runtime_info->version = runtime.version;
  CopyUtf8(out_runtime_info->revision, runtime.revision);
  CopyUtf8(out_runtime_info->error, runtime.error);
  return RC_RESULT_OK;
}

extern "C" RC_API rc_result rc_sdl_enumerate_gamepads(
    rc_input_device_info_v1* devices, const std::uint32_t capacity,
    std::uint32_t* out_count) {
  if (out_count == nullptr || (devices == nullptr && capacity != 0)) {
    return RC_RESULT_INVALID_ARGUMENT;
  }
  if (!remote_controller::backends::SdlInputBackend::GetRuntimeInfo()
           .available) {
    *out_count = 0;
    return RC_RESULT_BACKEND_FAILURE;
  }

  remote_controller::backends::SdlInputBackend backend;
  const auto found = backend.EnumerateDevices();
  *out_count = static_cast<std::uint32_t>(found.size());
  if (devices == nullptr) {
    return RC_RESULT_OK;
  }
  if (capacity < found.size()) {
    return RC_RESULT_BUFFER_TOO_SMALL;
  }

  for (std::size_t index = 0; index < found.size(); ++index) {
    if (devices[index].struct_size != sizeof(rc_input_device_info_v1)) {
      return RC_RESULT_INVALID_ARGUMENT;
    }
    const auto struct_size = devices[index].struct_size;
    devices[index] = {};
    devices[index].struct_size = struct_size;
    const auto& source = found[index];
    const auto parsed_instance_id = std::stoul(source.id);
    devices[index].instance_id =
        static_cast<std::uint32_t>(parsed_instance_id);
    devices[index].vendor_id = source.vendor_id;
    devices[index].product_id = source.product_id;
    devices[index].product_version = source.product_version;
    devices[index].gamepad_type = source.controller_type;
    devices[index].connection_state = source.connection_state;
    devices[index].capabilities = source.capabilities;
    devices[index].supported_buttons = source.supported_buttons;
    devices[index].flags = source.flags;
    CopyUtf8(devices[index].name, source.display_name);
    CopyUtf8(devices[index].path, source.device_path);
    CopyUtf8(devices[index].guid, source.guid);
  }
  return RC_RESULT_OK;
}

extern "C" RC_API rc_result rc_sdl_capture_create(
    const std::uint32_t instance_id, rc_input_capture** out_capture) {
  if (out_capture == nullptr) {
    return RC_RESULT_INVALID_ARGUMENT;
  }
  *out_capture = nullptr;
  if (!remote_controller::backends::SdlInputBackend::GetRuntimeInfo()
           .available) {
    return RC_RESULT_BACKEND_FAILURE;
  }
  auto capture = new (std::nothrow) rc_input_capture(instance_id);
  if (capture == nullptr) {
    return RC_RESULT_BACKEND_FAILURE;
  }
  *out_capture = capture;
  return RC_RESULT_OK;
}

extern "C" RC_API rc_result rc_input_capture_start(
    rc_input_capture* capture) {
  if (capture == nullptr) {
    return RC_RESULT_INVALID_ARGUMENT;
  }
  return ToAbiResult(capture->implementation.Start());
}

extern "C" RC_API rc_result rc_input_capture_get_snapshot(
    rc_input_capture* capture,
    rc_input_capture_snapshot_v1* out_snapshot) {
  if (capture == nullptr || out_snapshot == nullptr ||
      out_snapshot->struct_size != sizeof(rc_input_capture_snapshot_v1)) {
    return RC_RESULT_INVALID_ARGUMENT;
  }
  const auto struct_size = out_snapshot->struct_size;
  const auto source = capture->implementation.Snapshot();
  *out_snapshot = {};
  out_snapshot->struct_size = struct_size;
  out_snapshot->state = static_cast<std::uint32_t>(source.state);
  out_snapshot->sample_count = source.sample_count;
  out_snapshot->timestamp_us = source.timestamp_us;
  out_snapshot->current_state = ToAbiState(source.current_state);
  out_snapshot->observed_button_flags = source.observed_button_flags;
  out_snapshot->left_trigger_max = source.left_trigger_max;
  out_snapshot->right_trigger_max = source.right_trigger_max;
  out_snapshot->left_stick_x_min = source.left_stick_x_min;
  out_snapshot->left_stick_x_max = source.left_stick_x_max;
  out_snapshot->left_stick_y_min = source.left_stick_y_min;
  out_snapshot->left_stick_y_max = source.left_stick_y_max;
  out_snapshot->right_stick_x_min = source.right_stick_x_min;
  out_snapshot->right_stick_x_max = source.right_stick_x_max;
  out_snapshot->right_stick_y_min = source.right_stick_y_min;
  out_snapshot->right_stick_y_max = source.right_stick_y_max;
  return RC_RESULT_OK;
}

extern "C" RC_API rc_result rc_input_capture_stop(
    rc_input_capture* capture) {
  if (capture == nullptr) {
    return RC_RESULT_INVALID_ARGUMENT;
  }
  return ToAbiResult(capture->implementation.Stop());
}

extern "C" RC_API void rc_input_capture_destroy(
    rc_input_capture* capture) {
  delete capture;
}

extern "C" RC_API rc_result rc_session_create_loopback(
    const std::uint32_t input_timeout_ms, rc_session** out_session) {
  if (out_session == nullptr || input_timeout_ms < 10 ||
      input_timeout_ms > 5000) {
    return RC_RESULT_INVALID_ARGUMENT;
  }
  *out_session = nullptr;
  auto session = new (std::nothrow)
      rc_session(std::chrono::milliseconds(input_timeout_ms));
  if (session == nullptr) {
    return RC_RESULT_BACKEND_FAILURE;
  }
  *out_session = session;
  return RC_RESULT_OK;
}

extern "C" RC_API rc_result rc_session_start(rc_session* session) {
  if (session == nullptr) {
    return RC_RESULT_INVALID_ARGUMENT;
  }
  return ToAbiResult(session->implementation.Start());
}

extern "C" RC_API rc_result rc_session_submit_state(
    rc_session* session, const rc_gamepad_state_v1* state,
    const std::uint64_t sequence, const std::uint64_t timestamp_us) {
  if (session == nullptr || state == nullptr) {
    return RC_RESULT_INVALID_ARGUMENT;
  }
  return ToAbiResult(session->implementation.SubmitState(
      ToNativeState(*state), sequence, timestamp_us));
}

extern "C" RC_API rc_result rc_session_get_snapshot(
    rc_session* session, rc_session_snapshot_v1* out_snapshot) {
  if (session == nullptr || out_snapshot == nullptr ||
      out_snapshot->struct_size != sizeof(rc_session_snapshot_v1)) {
    return RC_RESULT_INVALID_ARGUMENT;
  }
  const auto snapshot = session->implementation.Snapshot();
  out_snapshot->state = static_cast<std::uint32_t>(snapshot.state);
  out_snapshot->latest_sequence = snapshot.latest_sequence;
  out_snapshot->accepted_state_count = snapshot.accepted_state_count;
  out_snapshot->neutralization_count = snapshot.neutralization_count;
  out_snapshot->last_input_timestamp_us = snapshot.last_input_timestamp_us;
  out_snapshot->output_state = ToAbiState(snapshot.output_state);
  return RC_RESULT_OK;
}

extern "C" RC_API rc_result rc_session_simulate_disconnect(
    rc_session* session) {
  if (session == nullptr) {
    return RC_RESULT_INVALID_ARGUMENT;
  }
  return ToAbiResult(session->implementation.SimulateDisconnect());
}

extern "C" RC_API rc_result rc_session_stop(rc_session* session) {
  if (session == nullptr) {
    return RC_RESULT_INVALID_ARGUMENT;
  }
  return ToAbiResult(session->implementation.Stop());
}

extern "C" RC_API void rc_session_destroy(rc_session* session) {
  delete session;
}
