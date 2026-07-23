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

typedef int32_t rc_result;

#define RC_RESULT_OK 0
#define RC_RESULT_INVALID_ARGUMENT 1
#define RC_RESULT_INVALID_STATE 2
#define RC_RESULT_STALE_SEQUENCE 3
#define RC_RESULT_BACKEND_FAILURE 4

#define RC_SESSION_STATE_CREATED 0
#define RC_SESSION_STATE_RUNNING 1
#define RC_SESSION_STATE_STOPPED 2
#define RC_SESSION_STATE_DISCONNECTED 3
#define RC_SESSION_STATE_FAULTED 4

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

// ABI version for the exported C interface. Increase only for breaking changes.
RC_API uint32_t rc_get_abi_version(void);

// Returns a process-lifetime UTF-8 string owned by the native library.
RC_API const char* rc_get_build_info(void);

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
