// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'package:remote_controller/data/models/loopback_diagnostic_data.dart';
import 'package:remote_controller_core/remote_controller_core.dart';

final class NativeCoreService {
  SdlInputCapture? _inputCapture;
  LocalControllerBridge? _localBridge;

  int getAbiVersion() => RemoteControllerCore.abiVersion;

  String getBuildInfo() => RemoteControllerCore.buildInfo;

  SdlRuntimeInfo getInputRuntime() => SdlInput.runtimeInfo;

  List<SdlGamepadDevice> enumerateInputDevices() => SdlInput.enumerateGamepads();

  VigemRuntimeInfo getVirtualControllerRuntime() => VigemController.runtimeInfo;

  void startInputCapture(int instanceId) {
    stopLocalBridge();
    stopInputCapture();
    final capture = SdlInput.createCapture(instanceId);
    try {
      capture.start();
      _inputCapture = capture;
    } on Object {
      capture.close();
      rethrow;
    }
  }

  SdlInputCaptureSnapshot getInputCaptureSnapshot() {
    final capture = _inputCapture;
    if (capture == null) {
      throw StateError('No SDL input capture is active.');
    }
    return capture.snapshot();
  }

  void stopInputCapture() {
    _inputCapture?.close();
    _inputCapture = null;
  }

  void startLocalBridge(int instanceId) {
    stopInputCapture();
    stopLocalBridge();
    final bridge = VigemController.createLocalBridge(instanceId);
    try {
      bridge.start();
      _localBridge = bridge;
    } on Object {
      bridge.close();
      rethrow;
    }
  }

  LocalBridgeSnapshot getLocalBridgeSnapshot() {
    final bridge = _localBridge;
    if (bridge == null) {
      throw StateError('No local controller bridge is active.');
    }
    return bridge.snapshot();
  }

  void stopLocalBridge() {
    _localBridge?.close();
    _localBridge = null;
  }

  void dispose() {
    stopInputCapture();
    stopLocalBridge();
  }

  Future<LoopbackDiagnosticData> runLoopbackDiagnostic() async {
    final stopwatch = Stopwatch()..start();
    final session = RemoteControllerCore.createLoopbackSession(
      inputTimeout: const Duration(milliseconds: 50),
    );
    try {
      session.start();
      session.submitState(
        const GamepadState(
          buttonFlags: GamepadButton.a,
          leftTrigger: 65535,
          rightTrigger: 32768,
          leftStickX: -32768,
          leftStickY: 32767,
          rightStickX: -1234,
          rightStickY: 4321,
        ),
        sequence: 1,
        timestampUs: stopwatch.elapsedMicroseconds,
      );

      final applied = await _waitForSnapshot(
        session,
        (snapshot) => snapshot.latestSequence == 1,
      );
      if (applied.outputState.buttonFlags != GamepadButton.a ||
          applied.outputState.leftTrigger != 65535 ||
          applied.outputState.rightTrigger != 32768 ||
          applied.outputState.leftStickX != -32768 ||
          applied.outputState.leftStickY != 32767 ||
          applied.outputState.rightStickX != -1234 ||
          applied.outputState.rightStickY != 4321) {
        throw StateError('Loopback changed raw controller values.');
      }

      final neutral = await _waitForSnapshot(
        session,
        (snapshot) => snapshot.neutralizationCount >= 1,
      );
      if (neutral.outputState.buttonFlags != 0 ||
          neutral.outputState.leftTrigger != 0 ||
          neutral.outputState.rightTrigger != 0) {
        throw StateError('Watchdog did not restore a neutral state.');
      }

      stopwatch.stop();
      return LoopbackDiagnosticData(
        acceptedStateCount: neutral.acceptedStateCount,
        neutralizationCount: neutral.neutralizationCount,
        elapsedMilliseconds: stopwatch.elapsedMilliseconds,
      );
    } finally {
      session.close();
    }
  }

  Future<NativeSessionSnapshot> _waitForSnapshot(
    LoopbackSession session,
    bool Function(NativeSessionSnapshot snapshot) predicate,
  ) async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (DateTime.now().isBefore(deadline)) {
      final snapshot = session.snapshot();
      if (predicate(snapshot)) {
        return snapshot;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw StateError('Native loopback diagnostic timed out.');
  }
}
