// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:remote_controller_core/src/gamepad_state.dart';
import 'package:remote_controller_core/src/third_party/remote_controller_core.g.dart' as native;

abstract final class RemoteControllerCore {
  static int get abiVersion => native.rc_get_abi_version();

  static String get buildInfo => native.rc_get_build_info().cast<Utf8>().toDartString();

  static LoopbackSession createLoopbackSession({
    Duration inputTimeout = const Duration(milliseconds: 100),
  }) => LoopbackSession._create(inputTimeout);
}

enum NativeSessionState {
  created(0),
  running(1),
  stopped(2),
  disconnected(3),
  faulted(4),
  unknown(-1);

  const NativeSessionState(this.nativeValue);

  final int nativeValue;

  static NativeSessionState fromNative(int value) => values.firstWhere(
    (state) => state.nativeValue == value,
    orElse: () => unknown,
  );
}

final class NativeSessionSnapshot {
  const NativeSessionSnapshot({
    required this.state,
    required this.latestSequence,
    required this.acceptedStateCount,
    required this.neutralizationCount,
    required this.lastInputTimestampUs,
    required this.outputState,
  });

  final NativeSessionState state;
  final int latestSequence;
  final int acceptedStateCount;
  final int neutralizationCount;
  final int lastInputTimestampUs;
  final GamepadState outputState;
}

final class NativeCoreException implements Exception {
  const NativeCoreException(this.operation, this.resultCode);

  final String operation;
  final int resultCode;

  @override
  String toString() => 'NativeCoreException($operation, result=$resultCode)';
}

final class LoopbackSession {
  LoopbackSession._(this._handle);

  static const int _resultOk = 0;

  Pointer<native.rc_session> _handle;
  bool _closed = false;

  static LoopbackSession _create(Duration inputTimeout) {
    final timeoutMs = inputTimeout.inMilliseconds;
    final outSession = calloc<Pointer<native.rc_session>>();
    try {
      _checkResult(
        'rc_session_create_loopback',
        native.rc_session_create_loopback(timeoutMs, outSession),
      );
      return LoopbackSession._(outSession.value);
    } finally {
      calloc.free(outSession);
    }
  }

  void start() {
    _ensureOpen();
    _checkResult('rc_session_start', native.rc_session_start(_handle));
  }

  void submitState(
    GamepadState state, {
    required int sequence,
    required int timestampUs,
  }) {
    _ensureOpen();
    final nativeState = calloc<native.rc_gamepad_state_v1>();
    try {
      nativeState.ref
        ..button_flags = state.buttonFlags
        ..left_trigger = state.leftTrigger
        ..right_trigger = state.rightTrigger
        ..left_stick_x = state.leftStickX
        ..left_stick_y = state.leftStickY
        ..right_stick_x = state.rightStickX
        ..right_stick_y = state.rightStickY;
      _checkResult(
        'rc_session_submit_state',
        native.rc_session_submit_state(
          _handle,
          nativeState,
          sequence,
          timestampUs,
        ),
      );
    } finally {
      calloc.free(nativeState);
    }
  }

  NativeSessionSnapshot snapshot() {
    _ensureOpen();
    final nativeSnapshot = calloc<native.rc_session_snapshot_v1>();
    try {
      nativeSnapshot.ref.struct_size = sizeOf<native.rc_session_snapshot_v1>();
      _checkResult(
        'rc_session_get_snapshot',
        native.rc_session_get_snapshot(_handle, nativeSnapshot),
      );
      final value = nativeSnapshot.ref;
      return NativeSessionSnapshot(
        state: NativeSessionState.fromNative(value.state),
        latestSequence: value.latest_sequence,
        acceptedStateCount: value.accepted_state_count,
        neutralizationCount: value.neutralization_count,
        lastInputTimestampUs: value.last_input_timestamp_us,
        outputState: GamepadState(
          buttonFlags: value.output_state.button_flags,
          leftTrigger: value.output_state.left_trigger,
          rightTrigger: value.output_state.right_trigger,
          leftStickX: value.output_state.left_stick_x,
          leftStickY: value.output_state.left_stick_y,
          rightStickX: value.output_state.right_stick_x,
          rightStickY: value.output_state.right_stick_y,
        ),
      );
    } finally {
      calloc.free(nativeSnapshot);
    }
  }

  void simulateDisconnect() {
    _ensureOpen();
    _checkResult(
      'rc_session_simulate_disconnect',
      native.rc_session_simulate_disconnect(_handle),
    );
  }

  void stop() {
    _ensureOpen();
    _checkResult('rc_session_stop', native.rc_session_stop(_handle));
  }

  void close() {
    if (_closed) {
      return;
    }
    native.rc_session_stop(_handle);
    native.rc_session_destroy(_handle);
    _handle = nullptr;
    _closed = true;
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('LoopbackSession is already closed.');
    }
  }

  static void _checkResult(String operation, int result) {
    if (result != _resultOk) {
      throw NativeCoreException(operation, result);
    }
  }
}
