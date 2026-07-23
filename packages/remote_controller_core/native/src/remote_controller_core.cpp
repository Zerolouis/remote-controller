// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#include "remote_controller_core.h"

#include <chrono>
#include <memory>
#include <new>

#include "controller_protocol.h"
#include "session.h"

namespace {

constexpr std::uint32_t kAbiVersion = 1;
constexpr char kBuildInfo[] =
    "remote-controller-core/0.2.0; abi=1; protocol=1; "
    "backends=loopback,memory-virtual; watchdog=100ms-default";

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

}  // namespace

struct rc_session {
  explicit rc_session(const std::chrono::milliseconds input_timeout)
      : implementation(input_timeout) {}

  remote_controller::Session implementation;
};

static_assert(sizeof(rc_gamepad_state_v1) ==
              sizeof(remote_controller::protocol::GamepadStateV1));
static_assert(sizeof(rc_session_snapshot_v1) == 56);

extern "C" RC_API std::uint32_t rc_get_abi_version(void) { return kAbiVersion; }

extern "C" RC_API const char* rc_get_build_info(void) { return kBuildInfo; }

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
