// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'dart:io';
import 'dart:isolate';

import 'package:remote_controller_core/remote_controller_core.dart';
import 'package:test/test.dart';

void main() {
  test('native smoke ABI is available through generated bindings', () {
    expect(RemoteControllerCore.abiVersion, 1);
    expect(RemoteControllerCore.buildInfo, contains('protocol=1'));
    expect(RemoteControllerCore.buildInfo, contains('sdl3'));
    expect(RemoteControllerCore.buildInfo, contains('vigem-x360'));
    expect(RemoteControllerCore.buildInfo, contains('vigem-installer-launch'));
    expect(RemoteControllerCore.buildInfo, contains('loopback'));
  });

  test('pinned SDL runtime loads and gamepad enumeration is safe', () {
    final runtime = SdlInput.runtimeInfo;
    expect(runtime.available, isTrue, reason: runtime.error);
    expect(runtime.versionLabel, '3.4.12');
    expect(runtime.error, isEmpty);

    final devices = SdlInput.enumerateGamepads();
    for (final device in devices) {
      expect(device.instanceId, greaterThanOrEqualTo(0));
      expect(device.name, isNotEmpty);
      expect(device.guid, hasLength(32));
    }
  });

  test('SDL capture reports a missing instance without leaking a handle', () {
    final capture = SdlInput.createCapture(0xffffffff);
    addTearDown(capture.close);

    expect(
      capture.start,
      throwsA(
        isA<NativeCoreException>().having(
          (error) => error.resultCode,
          'resultCode',
          4,
        ),
      ),
    );
    expect(capture.snapshot().state, NativeInputCaptureState.faulted);
  });

  test('ViGEmBus probe is safe and a failed local bridge cleans up', () {
    final runtime = VigemController.runtimeInfo;
    expect(runtime.resultCode, isNonNegative);
    expect(runtime.error.isEmpty, runtime.available);

    if (!runtime.available) {
      expect(runtime.error, isNotEmpty);
      return;
    }

    final bridge = VigemController.createLocalBridge(0xffffffff);
    addTearDown(bridge.close);
    expect(
      bridge.start,
      throwsA(
        isA<NativeCoreException>().having(
          (error) => error.resultCode,
          'resultCode',
          4,
        ),
      ),
    );
    expect(bridge.snapshot().state, LocalBridgeState.faulted);
  });

  test('ViGEmBus installer launcher is safe from a background isolate', () async {
    final result = await Isolate.run(
      () => VigemController.launchInstaller(
        r'Z:\remote-controller\missing\ViGEmBus-installer.exe',
      ),
    );

    expect(result.launched, isFalse);
    expect(result.win32Error, greaterThan(0));
  });

  test('native launcher rejects an installer that fails the pinned hash', () async {
    final directory = await Directory.systemTemp.createTemp(
      'remote-controller-native-installer-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final installer = File.fromUri(directory.uri.resolve('ViGEmBus.exe'));
    await installer.writeAsBytes(const [1, 2, 3, 4], flush: true);

    final result = await Isolate.run(
      () => VigemController.launchInstaller(installer.path),
    );

    expect(result.launched, isFalse);
    expect(result.win32Error, 13);
  });

  test('loopback preserves full raw state and rejects stale sequences', () async {
    final session = RemoteControllerCore.createLoopbackSession(
      inputTimeout: const Duration(milliseconds: 150),
    );
    addTearDown(session.close);

    session.start();
    const state = GamepadState(
      buttonFlags: GamepadButton.a | GamepadButton.leftShoulder,
      leftTrigger: 65535,
      rightTrigger: 32768,
      leftStickX: -32768,
      leftStickY: 32767,
      rightStickX: -1234,
      rightStickY: 4321,
    );
    session.submitState(state, sequence: 7, timestampUs: 123456789);

    final applied = await _waitFor(
      session,
      (snapshot) => snapshot.latestSequence == 7,
    );
    expect(applied.state, NativeSessionState.running);
    expect(applied.acceptedStateCount, 1);
    expect(applied.lastInputTimestampUs, 123456789);
    expect(applied.outputState.buttonFlags, state.buttonFlags);
    expect(applied.outputState.leftTrigger, 65535);
    expect(applied.outputState.rightTrigger, 32768);
    expect(applied.outputState.leftStickX, -32768);
    expect(applied.outputState.leftStickY, 32767);
    expect(applied.outputState.rightStickX, -1234);
    expect(applied.outputState.rightStickY, 4321);

    expect(
      () => session.submitState(state, sequence: 7, timestampUs: 123456790),
      throwsA(
        isA<NativeCoreException>().having(
          (error) => error.resultCode,
          'resultCode',
          3,
        ),
      ),
    );
  });

  test('watchdog and disconnect immediately restore neutral state', () async {
    final watchdogSession = RemoteControllerCore.createLoopbackSession(
      inputTimeout: const Duration(milliseconds: 50),
    );
    addTearDown(watchdogSession.close);
    watchdogSession.start();
    watchdogSession.submitState(
      const GamepadState(
        buttonFlags: GamepadButton.b,
        leftTrigger: 1,
        rightTrigger: 2,
        leftStickX: 3,
        leftStickY: 4,
        rightStickX: 5,
        rightStickY: 6,
      ),
      sequence: 1,
      timestampUs: 10,
    );

    await _waitFor(
      watchdogSession,
      (snapshot) => snapshot.latestSequence == 1,
    );
    final timedOut = await _waitFor(
      watchdogSession,
      (snapshot) => snapshot.neutralizationCount == 1,
    );
    expect(timedOut.outputState.buttonFlags, 0);
    expect(timedOut.outputState.leftTrigger, 0);
    expect(timedOut.state, NativeSessionState.running);

    final disconnectSession = RemoteControllerCore.createLoopbackSession(
      inputTimeout: const Duration(seconds: 1),
    );
    addTearDown(disconnectSession.close);
    disconnectSession.start();
    disconnectSession.submitState(
      const GamepadState(
        buttonFlags: GamepadButton.x,
        leftTrigger: 65535,
        rightTrigger: 65535,
        leftStickX: -1,
        leftStickY: 1,
        rightStickX: -2,
        rightStickY: 2,
      ),
      sequence: 1,
      timestampUs: 20,
    );
    await _waitFor(
      disconnectSession,
      (snapshot) => snapshot.latestSequence == 1,
    );
    disconnectSession.simulateDisconnect();

    final disconnected = disconnectSession.snapshot();
    expect(disconnected.state, NativeSessionState.disconnected);
    expect(disconnected.neutralizationCount, 1);
    expect(disconnected.outputState.buttonFlags, 0);
  });

  test('loopback never coalesces button press and release edges', () async {
    final session = RemoteControllerCore.createLoopbackSession(
      inputTimeout: const Duration(milliseconds: 500),
    );
    addTearDown(session.close);
    session.start();

    session.submitState(
      const GamepadState(
        buttonFlags: GamepadButton.a,
        leftTrigger: 0,
        rightTrigger: 0,
        leftStickX: 0,
        leftStickY: 0,
        rightStickX: 0,
        rightStickY: 0,
      ),
      sequence: 1,
      timestampUs: 1,
    );
    session.submitState(GamepadState.neutral, sequence: 2, timestampUs: 2);

    final released = await _waitFor(
      session,
      (snapshot) => snapshot.latestSequence == 2,
    );
    expect(released.acceptedStateCount, 2);
    expect(released.outputState.buttonFlags, 0);
  });
}

Future<NativeSessionSnapshot> _waitFor(
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
  throw TestFailure('Timed out waiting for native session state.');
}
