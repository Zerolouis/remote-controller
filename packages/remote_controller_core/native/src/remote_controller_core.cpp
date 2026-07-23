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
#include "backends/vigem_virtual_controller_backend.h"
#include "controller_protocol.h"
#include "input_capture.h"
#include "lan_controller_session.h"
#include "local_controller_bridge.h"
#include "pairing_key_store.h"
#include "session.h"
#include "vigem_installer.h"

namespace {

constexpr std::uint32_t kAbiVersion = 1;
constexpr char kBuildInfo[] =
    "remote-controller-core/0.7.0; abi=1; protocol=1; "
    "backends=sdl3,vigem-x360,udp-lan,loopback,memory-virtual; "
    "features=lan-trusted-plaintext,lan-pairing-key,vigem-installer-launch; "
    "watchdog=100ms-default";

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

void CopyLanSnapshot(const remote_controller::LanSessionSnapshot& source,
                     rc_lan_session_snapshot_v1& destination) {
  const auto struct_size = destination.struct_size;
  destination = {};
  destination.struct_size = struct_size;
  destination.state = static_cast<std::uint32_t>(source.state);
  destination.connected = source.connected ? 1U : 0U;
  destination.sent_packet_count = source.sent_packet_count;
  destination.received_packet_count = source.received_packet_count;
  destination.dropped_packet_count = source.dropped_packet_count;
  destination.neutralization_count = source.neutralization_count;
  destination.latest_sequence = source.latest_sequence;
  destination.last_input_timestamp_us = source.last_input_timestamp_us;
  destination.rumble_count = source.rumble_count;
  destination.current_state = ToAbiState(source.current_state);
  destination.low_frequency_motor = source.low_frequency_motor;
  destination.high_frequency_motor = source.high_frequency_motor;
  destination.last_error = source.last_error;
  CopyUtf8(destination.peer_address, source.peer_address);
  CopyUtf8(destination.error, source.error);
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

struct rc_local_controller_bridge {
  explicit rc_local_controller_bridge(const std::uint32_t instance_id)
      : implementation(
            std::make_unique<
                remote_controller::backends::SdlInputBackend>(),
            std::make_unique<remote_controller::backends::
                                 VigemVirtualControllerBackend>(),
            std::to_string(instance_id)) {}

  remote_controller::LocalControllerBridge implementation;
};

struct rc_lan_controller_client {
  rc_lan_controller_client(const std::uint32_t instance_id,
                           std::string server_address,
                           const std::uint16_t port,
                           const std::uint16_t pairing_key)
      : implementation(
            std::make_unique<remote_controller::backends::SdlInputBackend>(),
            std::make_unique<remote_controller::backends::
                                 UdpLanTransportBackend>(
                std::move(server_address), port, pairing_key),
            std::to_string(instance_id)) {}

  remote_controller::LanControllerClient implementation;
};

struct rc_lan_controller_server {
  rc_lan_controller_server(const std::uint16_t port,
                           const std::chrono::milliseconds input_timeout)
      : implementation(
            std::make_unique<remote_controller::backends::
                                 UdpLanTransportBackend>(port),
            std::make_unique<remote_controller::backends::
                                 VigemVirtualControllerBackend>(),
            input_timeout) {}

  remote_controller::LanControllerServer implementation;
};

static_assert(sizeof(rc_gamepad_state_v1) ==
              sizeof(remote_controller::protocol::GamepadStateV1));
static_assert(sizeof(rc_session_snapshot_v1) == 56);
static_assert(sizeof(rc_sdl_runtime_info_v1) == 336);
static_assert(sizeof(rc_input_device_info_v1) == 712);
static_assert(sizeof(rc_input_capture_snapshot_v1) == 64);
static_assert(sizeof(rc_vigem_runtime_info_v1) == 272);
static_assert(sizeof(rc_vigem_installer_launch_result_v1) == 16);
static_assert(sizeof(rc_local_bridge_snapshot_v1) == 56);
static_assert(sizeof(rc_lan_session_snapshot_v1) == 416);

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

extern "C" RC_API rc_result rc_vigem_get_runtime_info(
    rc_vigem_runtime_info_v1* out_runtime_info) {
  if (out_runtime_info == nullptr ||
      out_runtime_info->struct_size != sizeof(rc_vigem_runtime_info_v1)) {
    return RC_RESULT_INVALID_ARGUMENT;
  }
  const auto struct_size = out_runtime_info->struct_size;
  *out_runtime_info = {};
  out_runtime_info->struct_size = struct_size;

  const auto runtime = remote_controller::backends::
      VigemVirtualControllerBackend::Probe();
  out_runtime_info->available = runtime.available ? 1U : 0U;
  out_runtime_info->result_code = runtime.result_code;
  CopyUtf8(out_runtime_info->error, runtime.error);
  return RC_RESULT_OK;
}

extern "C" RC_API rc_result rc_vigem_launch_installer(
    const char* installer_path_utf8,
    rc_vigem_installer_launch_result_v1* out_launch_result) {
  if (installer_path_utf8 == nullptr || out_launch_result == nullptr ||
      out_launch_result->struct_size !=
          sizeof(rc_vigem_installer_launch_result_v1)) {
    return RC_RESULT_INVALID_ARGUMENT;
  }
  const auto struct_size = out_launch_result->struct_size;
  const auto result =
      remote_controller::LaunchVigemInstaller(installer_path_utf8);
  *out_launch_result = {};
  out_launch_result->struct_size = struct_size;
  out_launch_result->launched = result.launched ? 1U : 0U;
  out_launch_result->win32_error = result.win32_error;
  return RC_RESULT_OK;
}

extern "C" RC_API rc_result rc_local_bridge_create(
    const std::uint32_t instance_id,
    rc_local_controller_bridge** out_bridge) {
  if (out_bridge == nullptr) {
    return RC_RESULT_INVALID_ARGUMENT;
  }
  *out_bridge = nullptr;
  if (!remote_controller::backends::SdlInputBackend::GetRuntimeInfo()
           .available) {
    return RC_RESULT_BACKEND_FAILURE;
  }
  auto bridge = new (std::nothrow) rc_local_controller_bridge(instance_id);
  if (bridge == nullptr) {
    return RC_RESULT_BACKEND_FAILURE;
  }
  *out_bridge = bridge;
  return RC_RESULT_OK;
}

extern "C" RC_API rc_result rc_local_bridge_start(
    rc_local_controller_bridge* bridge) {
  if (bridge == nullptr) {
    return RC_RESULT_INVALID_ARGUMENT;
  }
  return ToAbiResult(bridge->implementation.Start());
}

extern "C" RC_API rc_result rc_local_bridge_get_snapshot(
    rc_local_controller_bridge* bridge,
    rc_local_bridge_snapshot_v1* out_snapshot) {
  if (bridge == nullptr || out_snapshot == nullptr ||
      out_snapshot->struct_size != sizeof(rc_local_bridge_snapshot_v1)) {
    return RC_RESULT_INVALID_ARGUMENT;
  }
  const auto struct_size = out_snapshot->struct_size;
  const auto source = bridge->implementation.Snapshot();
  *out_snapshot = {};
  out_snapshot->struct_size = struct_size;
  out_snapshot->state = static_cast<std::uint32_t>(source.state);
  out_snapshot->sample_count = source.sample_count;
  out_snapshot->timestamp_us = source.timestamp_us;
  out_snapshot->current_state = ToAbiState(source.current_state);
  out_snapshot->rumble_count = source.rumble_count;
  out_snapshot->low_frequency_motor = source.low_frequency_motor;
  out_snapshot->high_frequency_motor = source.high_frequency_motor;
  return RC_RESULT_OK;
}

extern "C" RC_API rc_result rc_local_bridge_stop(
    rc_local_controller_bridge* bridge) {
  if (bridge == nullptr) {
    return RC_RESULT_INVALID_ARGUMENT;
  }
  return ToAbiResult(bridge->implementation.Stop());
}

extern "C" RC_API void rc_local_bridge_destroy(
    rc_local_controller_bridge* bridge) {
  delete bridge;
}

extern "C" RC_API rc_result rc_lan_client_create(
    const std::uint32_t instance_id, const char* server_address_utf8,
    const std::uint16_t port, const std::uint16_t pairing_key,
    rc_lan_controller_client** out_client) {
  if (server_address_utf8 == nullptr || server_address_utf8[0] == '\0' ||
      port == 0 || pairing_key > 9999 || out_client == nullptr) {
    return RC_RESULT_INVALID_ARGUMENT;
  }
  *out_client = nullptr;
  if (!remote_controller::backends::SdlInputBackend::GetRuntimeInfo()
           .available) {
    return RC_RESULT_BACKEND_FAILURE;
  }
  auto client = new (std::nothrow) rc_lan_controller_client(
      instance_id, server_address_utf8, port, pairing_key);
  if (client == nullptr) {
    return RC_RESULT_BACKEND_FAILURE;
  }
  *out_client = client;
  return RC_RESULT_OK;
}

extern "C" RC_API rc_result rc_lan_client_start(
    rc_lan_controller_client* client) {
  if (client == nullptr) {
    return RC_RESULT_INVALID_ARGUMENT;
  }
  return ToAbiResult(client->implementation.Start());
}

extern "C" RC_API rc_result rc_lan_client_get_snapshot(
    rc_lan_controller_client* client,
    rc_lan_session_snapshot_v1* out_snapshot) {
  if (client == nullptr || out_snapshot == nullptr ||
      out_snapshot->struct_size != sizeof(rc_lan_session_snapshot_v1)) {
    return RC_RESULT_INVALID_ARGUMENT;
  }
  CopyLanSnapshot(client->implementation.Snapshot(), *out_snapshot);
  return RC_RESULT_OK;
}

extern "C" RC_API rc_result rc_lan_client_stop(
    rc_lan_controller_client* client) {
  if (client == nullptr) {
    return RC_RESULT_INVALID_ARGUMENT;
  }
  return ToAbiResult(client->implementation.Stop());
}

extern "C" RC_API void rc_lan_client_destroy(
    rc_lan_controller_client* client) {
  delete client;
}

extern "C" RC_API rc_result rc_lan_server_create(
    const std::uint16_t port, const std::uint32_t input_timeout_ms,
    rc_lan_controller_server** out_server) {
  if (port == 0 || input_timeout_ms < 10 || input_timeout_ms > 5000 ||
      out_server == nullptr) {
    return RC_RESULT_INVALID_ARGUMENT;
  }
  *out_server = nullptr;
  auto server = new (std::nothrow) rc_lan_controller_server(
      port, std::chrono::milliseconds(input_timeout_ms));
  if (server == nullptr) {
    return RC_RESULT_BACKEND_FAILURE;
  }
  *out_server = server;
  return RC_RESULT_OK;
}

extern "C" RC_API rc_result rc_lan_server_start(
    rc_lan_controller_server* server) {
  if (server == nullptr) {
    return RC_RESULT_INVALID_ARGUMENT;
  }
  return ToAbiResult(server->implementation.Start());
}

extern "C" RC_API rc_result rc_lan_server_get_snapshot(
    rc_lan_controller_server* server,
    rc_lan_session_snapshot_v1* out_snapshot) {
  if (server == nullptr || out_snapshot == nullptr ||
      out_snapshot->struct_size != sizeof(rc_lan_session_snapshot_v1)) {
    return RC_RESULT_INVALID_ARGUMENT;
  }
  CopyLanSnapshot(server->implementation.Snapshot(), *out_snapshot);
  return RC_RESULT_OK;
}

extern "C" RC_API rc_result rc_lan_server_stop(
    rc_lan_controller_server* server) {
  if (server == nullptr) {
    return RC_RESULT_INVALID_ARGUMENT;
  }
  return ToAbiResult(server->implementation.Stop());
}

extern "C" RC_API void rc_lan_server_destroy(
    rc_lan_controller_server* server) {
  delete server;
}

extern "C" RC_API rc_result rc_pairing_get_code(std::uint16_t* out_code) {
  if (out_code == nullptr) {
    return RC_RESULT_INVALID_ARGUMENT;
  }
  *out_code = remote_controller::PairingKeyStore::Get();
  return RC_RESULT_OK;
}

extern "C" RC_API rc_result rc_pairing_regenerate(
    std::uint16_t* out_new_code) {
  if (out_new_code == nullptr) {
    return RC_RESULT_INVALID_ARGUMENT;
  }
  *out_new_code = remote_controller::PairingKeyStore::Regenerate();
  return RC_RESULT_OK;
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
