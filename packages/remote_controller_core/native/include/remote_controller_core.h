// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#ifndef REMOTE_CONTROLLER_CORE_H_
#define REMOTE_CONTROLLER_CORE_H_

#include <stdint.h>

#if defined(_WIN32)
#if defined(RC_BUILDING_DLL)
#define RC_API __declspec(dllexport)
#else
#define RC_API __declspec(dllimport)
#endif
#else
#define RC_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct rc_session rc_session;
typedef struct rc_input_capture rc_input_capture;
typedef struct rc_local_controller_bridge rc_local_controller_bridge;
typedef struct rc_lan_controller_client rc_lan_controller_client;
typedef struct rc_lan_controller_server rc_lan_controller_server;

typedef int32_t rc_result;

#define RC_RESULT_OK 0
#define RC_RESULT_INVALID_ARGUMENT 1
#define RC_RESULT_INVALID_STATE 2
#define RC_RESULT_STALE_SEQUENCE 3
#define RC_RESULT_BACKEND_FAILURE 4
#define RC_RESULT_NOT_FOUND 5
#define RC_RESULT_BUFFER_TOO_SMALL 6

#define RC_SESSION_STATE_CREATED 0
#define RC_SESSION_STATE_RUNNING 1
#define RC_SESSION_STATE_STOPPED 2
#define RC_SESSION_STATE_DISCONNECTED 3
#define RC_SESSION_STATE_FAULTED 4

#define RC_INPUT_CAP_ANALOG_TRIGGERS (1U << 0)
#define RC_INPUT_CAP_RUMBLE (1U << 1)
#define RC_INPUT_CAP_TRIGGER_RUMBLE (1U << 2)

#define RC_INPUT_DEVICE_FLAG_ROG_ALLY_X (1U << 0)

#define RC_INPUT_DEVICE_NAME_CAPACITY 128
#define RC_INPUT_DEVICE_PATH_CAPACITY 512
#define RC_INPUT_DEVICE_GUID_CAPACITY 33
#define RC_SDL_REVISION_CAPACITY 64
#define RC_ERROR_MESSAGE_CAPACITY 256

typedef struct rc_gamepad_state_v1 {
  uint32_t button_flags;
  uint16_t left_trigger;
  uint16_t right_trigger;
  int16_t left_stick_x;
  int16_t left_stick_y;
  int16_t right_stick_x;
  int16_t right_stick_y;
} rc_gamepad_state_v1;

typedef struct rc_session_snapshot_v1 {
  uint32_t struct_size;
  uint32_t state;
  uint64_t latest_sequence;
  uint64_t accepted_state_count;
  uint64_t neutralization_count;
  uint64_t last_input_timestamp_us;
  rc_gamepad_state_v1 output_state;
} rc_session_snapshot_v1;

typedef struct rc_sdl_runtime_info_v1 {
  uint32_t struct_size;
  uint32_t available;
  uint32_t version;
  uint32_t reserved;
  char revision[RC_SDL_REVISION_CAPACITY];
  char error[RC_ERROR_MESSAGE_CAPACITY];
} rc_sdl_runtime_info_v1;

typedef struct rc_input_device_info_v1 {
  uint32_t struct_size;
  uint32_t instance_id;
  uint16_t vendor_id;
  uint16_t product_id;
  uint16_t product_version;
  uint16_t reserved;
  uint32_t gamepad_type;
  int32_t connection_state;
  uint32_t capabilities;
  uint32_t supported_buttons;
  uint32_t flags;
  char name[RC_INPUT_DEVICE_NAME_CAPACITY];
  char path[RC_INPUT_DEVICE_PATH_CAPACITY];
  char guid[RC_INPUT_DEVICE_GUID_CAPACITY];
  uint8_t reserved_tail[3];
} rc_input_device_info_v1;

typedef struct rc_input_capture_snapshot_v1 {
  uint32_t struct_size;
  uint32_t state;
  uint64_t sample_count;
  uint64_t timestamp_us;
  rc_gamepad_state_v1 current_state;
  uint32_t observed_button_flags;
  uint16_t left_trigger_max;
  uint16_t right_trigger_max;
  int16_t left_stick_x_min;
  int16_t left_stick_x_max;
  int16_t left_stick_y_min;
  int16_t left_stick_y_max;
  int16_t right_stick_x_min;
  int16_t right_stick_x_max;
  int16_t right_stick_y_min;
  int16_t right_stick_y_max;
} rc_input_capture_snapshot_v1;

typedef struct rc_vigem_runtime_info_v1 {
  uint32_t struct_size;
  uint32_t available;
  uint32_t result_code;
  uint32_t reserved;
  char error[RC_ERROR_MESSAGE_CAPACITY];
} rc_vigem_runtime_info_v1;

typedef struct rc_vigem_installer_launch_result_v1 {
  uint32_t struct_size;
  uint32_t launched;
  uint32_t win32_error;
  uint32_t reserved;
} rc_vigem_installer_launch_result_v1;

typedef struct rc_local_bridge_snapshot_v1 {
  uint32_t struct_size;
  uint32_t state;
  uint64_t sample_count;
  uint64_t timestamp_us;
  rc_gamepad_state_v1 current_state;
  uint64_t rumble_count;
  uint16_t low_frequency_motor;
  uint16_t high_frequency_motor;
  uint32_t reserved;
} rc_local_bridge_snapshot_v1;

typedef struct rc_lan_session_snapshot_v1 {
  uint32_t struct_size;
  uint32_t state;
  uint32_t connected;
  uint32_t reserved;
  uint64_t sent_packet_count;
  uint64_t received_packet_count;
  uint64_t dropped_packet_count;
  uint64_t neutralization_count;
  uint64_t latest_sequence;
  uint64_t last_input_timestamp_us;
  uint64_t rumble_count;
  rc_gamepad_state_v1 current_state;
  uint16_t low_frequency_motor;
  uint16_t high_frequency_motor;
  uint32_t last_error;
  char peer_address[64];
  char error[RC_ERROR_MESSAGE_CAPACITY];
} rc_lan_session_snapshot_v1;

// ABI version for the exported C interface. Increase only for breaking changes.
RC_API uint32_t rc_get_abi_version(void);

// Returns a process-lifetime UTF-8 string owned by the native library.
RC_API const char* rc_get_build_info(void);

// Returns availability, exact runtime version, revision and initialization
// error for the pinned SDL runtime. This function itself succeeds when SDL is
// unavailable so callers can display the diagnostic error.
RC_API rc_result rc_sdl_get_runtime_info(
    rc_sdl_runtime_info_v1* out_runtime_info);

// Two-pass enumeration. Call with devices=NULL and capacity=0 to query count.
// On RC_RESULT_BUFFER_TOO_SMALL, out_count contains the new required count.
RC_API rc_result rc_sdl_enumerate_gamepads(
    rc_input_device_info_v1* devices, uint32_t capacity,
    uint32_t* out_count);

RC_API rc_result rc_sdl_capture_create(uint32_t instance_id,
                                       rc_input_capture** out_capture);
RC_API rc_result rc_input_capture_start(rc_input_capture* capture);
RC_API rc_result rc_input_capture_get_snapshot(
    rc_input_capture* capture,
    rc_input_capture_snapshot_v1* out_snapshot);
RC_API rc_result rc_input_capture_stop(rc_input_capture* capture);
RC_API void rc_input_capture_destroy(rc_input_capture* capture);

// Probes whether a compatible ViGEmBus driver can be opened.
RC_API rc_result rc_vigem_get_runtime_info(
    rc_vigem_runtime_info_v1* out_runtime_info);

// Verifies the pinned ViGEmBus installer and launches it through Windows UAC.
RC_API rc_result rc_vigem_launch_installer(
    const char* installer_path_utf8,
    rc_vigem_installer_launch_result_v1* out_launch_result);

// Native-only SDL -> ViGEm diagnostic bridge. It does not enable HidHide and
// must not be used as the production network session ABI.
RC_API rc_result rc_local_bridge_create(
    uint32_t instance_id, rc_local_controller_bridge** out_bridge);
RC_API rc_result rc_local_bridge_start(rc_local_controller_bridge* bridge);
RC_API rc_result rc_local_bridge_get_snapshot(
    rc_local_controller_bridge* bridge,
    rc_local_bridge_snapshot_v1* out_snapshot);
RC_API rc_result rc_local_bridge_stop(rc_local_controller_bridge* bridge);
RC_API void rc_local_bridge_destroy(rc_local_controller_bridge* bridge);

// Plaintext LAN diagnostic path used to validate the split Client/Server
// controller chain before pairing and AEAD are enabled. Trusted LAN only.
RC_API rc_result rc_lan_client_create(
    uint32_t instance_id, const char* server_address_utf8, uint16_t port,
    rc_lan_controller_client** out_client);
RC_API rc_result rc_lan_client_start(rc_lan_controller_client* client);
RC_API rc_result rc_lan_client_get_snapshot(
    rc_lan_controller_client* client,
    rc_lan_session_snapshot_v1* out_snapshot);
RC_API rc_result rc_lan_client_stop(rc_lan_controller_client* client);
RC_API void rc_lan_client_destroy(rc_lan_controller_client* client);

RC_API rc_result rc_lan_server_create(
    uint16_t port, uint32_t input_timeout_ms,
    rc_lan_controller_server** out_server);
RC_API rc_result rc_lan_server_start(rc_lan_controller_server* server);
RC_API rc_result rc_lan_server_get_snapshot(
    rc_lan_controller_server* server,
    rc_lan_session_snapshot_v1* out_snapshot);
RC_API rc_result rc_lan_server_stop(rc_lan_controller_server* server);
RC_API void rc_lan_server_destroy(rc_lan_controller_server* server);

// Creates a native-only loopback session used to validate the common input
// pipeline before hardware and network backends are attached.
RC_API rc_result rc_session_create_loopback(uint32_t input_timeout_ms,
                                            rc_session** out_session);

RC_API rc_result rc_session_start(rc_session* session);

RC_API rc_result rc_session_submit_state(rc_session* session,
                                         const rc_gamepad_state_v1* state,
                                         uint64_t sequence,
                                         uint64_t timestamp_us);

RC_API rc_result rc_session_get_snapshot(rc_session* session,
                                         rc_session_snapshot_v1* out_snapshot);

// Diagnostic hook that exercises the same immediate-neutral path used by a
// future network backend when its control channel closes.
RC_API rc_result rc_session_simulate_disconnect(rc_session* session);

RC_API rc_result rc_session_stop(rc_session* session);

RC_API void rc_session_destroy(rc_session* session);

#ifdef __cplusplus
}
#endif

#endif  // REMOTE_CONTROLLER_CORE_H_
