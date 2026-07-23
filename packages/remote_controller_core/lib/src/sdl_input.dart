// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:remote_controller_core/src/gamepad_state.dart';
import 'package:remote_controller_core/src/native_core.dart';
import 'package:remote_controller_core/src/third_party/remote_controller_core.g.dart' as native;

abstract final class InputCapability {
  static const int analogTriggers = 1 << 0;
  static const int rumble = 1 << 1;
  static const int triggerRumble = 1 << 2;
}

final class SdlRuntimeInfo {
  const SdlRuntimeInfo({
    required this.available,
    required this.version,
    required this.revision,
    required this.error,
  });

  final bool available;
  final int version;
  final String revision;
  final String error;

  int get majorVersion => version ~/ 1000000;
  int get minorVersion => version ~/ 1000 % 1000;
  int get patchVersion => version % 1000;
  String get versionLabel => '$majorVersion.$minorVersion.$patchVersion';
}

final class SdlGamepadDevice {
  const SdlGamepadDevice({
    required this.instanceId,
    required this.name,
    required this.path,
    required this.guid,
    required this.vendorId,
    required this.productId,
    required this.productVersion,
    required this.gamepadType,
    required this.connectionState,
    required this.capabilities,
    required this.supportedButtons,
    required this.isRogAllyX,
  });

  final int instanceId;
  final String name;
  final String path;
  final String guid;
  final int vendorId;
  final int productId;
  final int productVersion;
  final int gamepadType;
  final int connectionState;
  final int capabilities;
  final int supportedButtons;
  final bool isRogAllyX;

  bool hasCapability(int capability) => capabilities & capability != 0;
}

enum NativeInputCaptureState {
  created(0),
  running(1),
  stopped(2),
  disconnected(3),
  faulted(4),
  unknown(-1);

  const NativeInputCaptureState(this.nativeValue);

  final int nativeValue;

  static NativeInputCaptureState fromNative(int value) => values.firstWhere(
    (state) => state.nativeValue == value,
    orElse: () => unknown,
  );
}

final class SdlInputCaptureSnapshot {
  const SdlInputCaptureSnapshot({
    required this.state,
    required this.sampleCount,
    required this.timestampUs,
    required this.currentState,
    required this.observedButtonFlags,
    required this.leftTriggerMax,
    required this.rightTriggerMax,
    required this.leftStickXMin,
    required this.leftStickXMax,
    required this.leftStickYMin,
    required this.leftStickYMax,
    required this.rightStickXMin,
    required this.rightStickXMax,
    required this.rightStickYMin,
    required this.rightStickYMax,
  });

  final NativeInputCaptureState state;
  final int sampleCount;
  final int timestampUs;
  final GamepadState currentState;
  final int observedButtonFlags;
  final int leftTriggerMax;
  final int rightTriggerMax;
  final int leftStickXMin;
  final int leftStickXMax;
  final int leftStickYMin;
  final int leftStickYMax;
  final int rightStickXMin;
  final int rightStickXMax;
  final int rightStickYMin;
  final int rightStickYMax;
}

abstract final class SdlInput {
  static const int _resultOk = 0;
  static const int _resultBufferTooSmall = 6;

  static SdlRuntimeInfo get runtimeInfo {
    final info = calloc<native.rc_sdl_runtime_info_v1>();
    try {
      info.ref.struct_size = sizeOf<native.rc_sdl_runtime_info_v1>();
      _checkResult(
        'rc_sdl_get_runtime_info',
        native.rc_sdl_get_runtime_info(info),
      );
      return SdlRuntimeInfo(
        available: info.ref.available != 0,
        version: info.ref.version,
        revision: _decodeChars(info.ref.revision, 64),
        error: _decodeChars(info.ref.error, 256),
      );
    } finally {
      calloc.free(info);
    }
  }

  static List<SdlGamepadDevice> enumerateGamepads() {
    final count = calloc<Uint32>();
    try {
      _checkResult(
        'rc_sdl_enumerate_gamepads(count)',
        native.rc_sdl_enumerate_gamepads(nullptr, 0, count),
      );
      for (var attempt = 0; attempt < 3; ++attempt) {
        final capacity = count.value;
        if (capacity == 0) {
          return const [];
        }
        final devices = calloc<native.rc_input_device_info_v1>(capacity);
        try {
          for (var index = 0; index < capacity; ++index) {
            (devices + index).ref.struct_size = sizeOf<native.rc_input_device_info_v1>();
          }
          final result = native.rc_sdl_enumerate_gamepads(
            devices,
            capacity,
            count,
          );
          if (result == _resultBufferTooSmall) {
            continue;
          }
          _checkResult('rc_sdl_enumerate_gamepads', result);
          return List<SdlGamepadDevice>.generate(count.value, (index) {
            final device = (devices + index).ref;
            return SdlGamepadDevice(
              instanceId: device.instance_id,
              name: _decodeChars(device.name, 128),
              path: _decodeChars(device.path, 512),
              guid: _decodeChars(device.guid, 33),
              vendorId: device.vendor_id,
              productId: device.product_id,
              productVersion: device.product_version,
              gamepadType: device.gamepad_type,
              connectionState: device.connection_state,
              capabilities: device.capabilities,
              supportedButtons: device.supported_buttons,
              isRogAllyX: device.flags & 1 != 0,
            );
          }, growable: false);
        } finally {
          calloc.free(devices);
        }
      }
      throw StateError('SDL gamepad list changed repeatedly during enumeration.');
    } finally {
      calloc.free(count);
    }
  }

  static SdlInputCapture createCapture(int instanceId) => SdlInputCapture._create(instanceId);

  static void _checkResult(String operation, int result) {
    if (result != _resultOk) {
      throw NativeCoreException(operation, result);
    }
  }
}

final class SdlInputCapture {
  SdlInputCapture._(this._handle);

  Pointer<native.rc_input_capture> _handle;
  bool _closed = false;

  static SdlInputCapture _create(int instanceId) {
    final outCapture = calloc<Pointer<native.rc_input_capture>>();
    try {
      SdlInput._checkResult(
        'rc_sdl_capture_create',
        native.rc_sdl_capture_create(instanceId, outCapture),
      );
      return SdlInputCapture._(outCapture.value);
    } finally {
      calloc.free(outCapture);
    }
  }

  void start() {
    _ensureOpen();
    SdlInput._checkResult(
      'rc_input_capture_start',
      native.rc_input_capture_start(_handle),
    );
  }

  SdlInputCaptureSnapshot snapshot() {
    _ensureOpen();
    final snapshot = calloc<native.rc_input_capture_snapshot_v1>();
    try {
      snapshot.ref.struct_size = sizeOf<native.rc_input_capture_snapshot_v1>();
      SdlInput._checkResult(
        'rc_input_capture_get_snapshot',
        native.rc_input_capture_get_snapshot(_handle, snapshot),
      );
      final value = snapshot.ref;
      return SdlInputCaptureSnapshot(
        state: NativeInputCaptureState.fromNative(value.state),
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
        observedButtonFlags: value.observed_button_flags,
        leftTriggerMax: value.left_trigger_max,
        rightTriggerMax: value.right_trigger_max,
        leftStickXMin: value.left_stick_x_min,
        leftStickXMax: value.left_stick_x_max,
        leftStickYMin: value.left_stick_y_min,
        leftStickYMax: value.left_stick_y_max,
        rightStickXMin: value.right_stick_x_min,
        rightStickXMax: value.right_stick_x_max,
        rightStickYMin: value.right_stick_y_min,
        rightStickYMax: value.right_stick_y_max,
      );
    } finally {
      calloc.free(snapshot);
    }
  }

  void stop() {
    _ensureOpen();
    SdlInput._checkResult(
      'rc_input_capture_stop',
      native.rc_input_capture_stop(_handle),
    );
  }

  void close() {
    if (_closed) {
      return;
    }
    native.rc_input_capture_stop(_handle);
    native.rc_input_capture_destroy(_handle);
    _handle = nullptr;
    _closed = true;
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('SdlInputCapture is already closed.');
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
