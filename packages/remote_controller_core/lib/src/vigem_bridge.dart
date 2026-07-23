// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:remote_controller_core/src/gamepad_state.dart';
import 'package:remote_controller_core/src/native_core.dart';
import 'package:remote_controller_core/src/third_party/remote_controller_core.g.dart' as native;

final class VigemRuntimeInfo {
  const VigemRuntimeInfo({
    required this.available,
    required this.resultCode,
    required this.error,
  });

  final bool available;
  final int resultCode;
  final String error;
}

final class VigemInstallerLaunchResult {
  const VigemInstallerLaunchResult({
    required this.launched,
    required this.win32Error,
  });

  final bool launched;
  final int win32Error;
}

enum LocalBridgeState {
  created(0),
  running(1),
  stopped(2),
  disconnected(3),
  faulted(4),
  unknown(-1);

  const LocalBridgeState(this.nativeValue);

  final int nativeValue;

  static LocalBridgeState fromNative(int value) => values.firstWhere(
    (state) => state.nativeValue == value,
    orElse: () => unknown,
  );
}

final class LocalBridgeSnapshot {
  const LocalBridgeSnapshot({
    required this.state,
    required this.sampleCount,
    required this.timestampUs,
    required this.currentState,
    required this.rumbleCount,
    required this.lowFrequencyMotor,
    required this.highFrequencyMotor,
  });

  final LocalBridgeState state;
  final int sampleCount;
  final int timestampUs;
  final GamepadState currentState;
  final int rumbleCount;
  final int lowFrequencyMotor;
  final int highFrequencyMotor;
}

abstract final class VigemController {
  static const int _resultOk = 0;

  static VigemRuntimeInfo get runtimeInfo {
    final info = calloc<native.rc_vigem_runtime_info_v1>();
    try {
      info.ref.struct_size = sizeOf<native.rc_vigem_runtime_info_v1>();
      _checkResult(
        'rc_vigem_get_runtime_info',
        native.rc_vigem_get_runtime_info(info),
      );
      return VigemRuntimeInfo(
        available: info.ref.available != 0,
        resultCode: info.ref.result_code,
        error: _decodeChars(info.ref.error, 256),
      );
    } finally {
      calloc.free(info);
    }
  }

  static VigemInstallerLaunchResult launchInstaller(String installerPath) {
    final path = installerPath.toNativeUtf8();
    final result = calloc<native.rc_vigem_installer_launch_result_v1>();
    try {
      result.ref.struct_size = sizeOf<native.rc_vigem_installer_launch_result_v1>();
      _checkResult(
        'rc_vigem_launch_installer',
        native.rc_vigem_launch_installer(path.cast(), result),
      );
      return VigemInstallerLaunchResult(
        launched: result.ref.launched != 0,
        win32Error: result.ref.win32_error,
      );
    } finally {
      calloc.free(result);
      calloc.free(path);
    }
  }

  static LocalControllerBridge createLocalBridge(int instanceId) =>
      LocalControllerBridge._create(instanceId);

  static void _checkResult(String operation, int result) {
    if (result != _resultOk) {
      throw NativeCoreException(operation, result);
    }
  }
}

final class LocalControllerBridge {
  LocalControllerBridge._(this._handle);

  Pointer<native.rc_local_controller_bridge> _handle;
  bool _closed = false;

  static LocalControllerBridge _create(int instanceId) {
    final outBridge = calloc<Pointer<native.rc_local_controller_bridge>>();
    try {
      VigemController._checkResult(
        'rc_local_bridge_create',
        native.rc_local_bridge_create(instanceId, outBridge),
      );
      return LocalControllerBridge._(outBridge.value);
    } finally {
      calloc.free(outBridge);
    }
  }

  void start() {
    _ensureOpen();
    VigemController._checkResult(
      'rc_local_bridge_start',
      native.rc_local_bridge_start(_handle),
    );
  }

  LocalBridgeSnapshot snapshot() {
    _ensureOpen();
    final snapshot = calloc<native.rc_local_bridge_snapshot_v1>();
    try {
      snapshot.ref.struct_size = sizeOf<native.rc_local_bridge_snapshot_v1>();
      VigemController._checkResult(
        'rc_local_bridge_get_snapshot',
        native.rc_local_bridge_get_snapshot(_handle, snapshot),
      );
      final value = snapshot.ref;
      return LocalBridgeSnapshot(
        state: LocalBridgeState.fromNative(value.state),
        sampleCount: value.sample_count,
        timestampUs: value.timestamp_us,
        currentState: GamepadState(
          buttonFlags: value.current_state.button_flags,
          leftTrigger: value.current_state.left_trigger,
          rightTrigger: value.current_state.right_trigger,
          leftStickX: value.current_state.left_stick_x,
          leftStickY: value.current_state.left_stick_y,
          rightStickX: value.current_state.right_stick_x,
          rightStickY: value.current_state.right_stick_y,
        ),
        rumbleCount: value.rumble_count,
        lowFrequencyMotor: value.low_frequency_motor,
        highFrequencyMotor: value.high_frequency_motor,
      );
    } finally {
      calloc.free(snapshot);
    }
  }

  void stop() {
    _ensureOpen();
    VigemController._checkResult(
      'rc_local_bridge_stop',
      native.rc_local_bridge_stop(_handle),
    );
  }

  void close() {
    if (_closed) {
      return;
    }
    native.rc_local_bridge_stop(_handle);
    native.rc_local_bridge_destroy(_handle);
    _handle = nullptr;
    _closed = true;
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('LocalControllerBridge is already closed.');
    }
  }
}

String _decodeChars(Array<Char> chars, int capacity) {
  final bytes = <int>[];
  for (var index = 0; index < capacity; ++index) {
    final value = chars[index] & 0xff;
    if (value == 0) {
      break;
    }
    bytes.add(value);
  }
  return utf8.decode(bytes, allowMalformed: true);
}
