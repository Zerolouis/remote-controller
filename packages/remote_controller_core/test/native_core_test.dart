// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:remote_controller_core/remote_controller_core.dart';
import 'package:test/test.dart';

typedef _SetEnvironmentVariableWNative = Int32 Function(
  Pointer<Utf16>,
  Pointer<Utf16>,
);
typedef _SetEnvironmentVariableWDart = int Function(
  Pointer<Utf16>,
  Pointer<Utf16>,
);

final _setEnvironmentVariableW = DynamicLibrary.open('kernel32.dll')
    .lookup<NativeFunction<_SetEnvironmentVariableWNative>>(
      'SetEnvironmentVariableW',
    )
    .asFunction<_SetEnvironmentVariableWDart>();

// Points the native PairingKeyStore at an isolated temp file so pairing tests
// never touch the developer's real %APPDATA% store. Uses the Win32 API because
// the native side reads the live process environment block.
void _setPairingStorePath(String? path) {
  final name = 'REMOTE_CONTROLLER_PAIRING_FILE'.toNativeUtf16();
  final value = path?.toNativeUtf16() ?? nullptr;
  try {
    _setEnvironmentVariableW(name, value);
  } finally {
    malloc.free(name);
    if (value != nullptr) {
      malloc.free(value);
    }
  }
}

void main() {
  late Directory pairingTempDir;
  setUpAll(() {
    pairingTempDir = Directory.systemTemp.createTempSync('rc_pairing_test_');
    _setPairingStorePath('${pairingTempDir.path}\\pairing_key.json');
  });
  tearDownAll(() {
    _setPairingStorePath(null);
    if (pairingTempDir.existsSync()) {
      pairingTempDir.deleteSync(recursive: true);
    }
  });

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

  test('trusted LAN server accepts full UDP state and watchdog neutralizes', () async {
    if (!VigemController.runtimeInfo.available) {
      return;
    }
    final portProbe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = portProbe.port;
    await portProbe.close();

    final server = LanController.createServer(
      port: port,
      inputTimeout: const Duration(milliseconds: 80),
    );
    addTearDown(server.close);
    server.start();

    Socket? control;
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (control == null && DateTime.now().isBefore(deadline)) {
      try {
        control = await Socket.connect(
          InternetAddress.loopbackIPv4,
          port,
          timeout: const Duration(milliseconds: 200),
        );
      } on SocketException {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
    expect(control, isNotNull);
    addTearDown(() => control?.destroy());

    const sessionId = 0x12345678;
    control!.add(
      _controlFrame(
        type: 1,
        sessionId: sessionId,
        pairingKey: LanController.pairingCode(),
      ),
    );
    await control.flush();
    final ack = await _readBytes(control, 32);
    expect(ByteData.sublistView(ack).getUint8(5), 2);

    final udp = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(udp.close);
    udp.send(
      _inputPacket(sessionId: sessionId),
      InternetAddress.loopbackIPv4,
      port,
    );

    final applied = await _waitForLan(
      server,
      (snapshot) => snapshot.receivedPacketCount == 1,
    );
    expect(applied.connected, isTrue);
    expect(applied.latestSequence, 7);
    expect(applied.currentState.buttonFlags, GamepadButton.a);
    expect(applied.currentState.leftTrigger, 65535);
    expect(applied.currentState.rightTrigger, 32768);
    expect(applied.currentState.leftStickX, -32768);
    expect(applied.currentState.leftStickY, 32767);

    final neutral = await _waitForLan(
      server,
      (snapshot) => snapshot.neutralizationCount >= 1,
    );
    expect(neutral.currentState.buttonFlags, 0);
    expect(neutral.currentState.leftTrigger, 0);
  });

  test('LAN native client streams an attached SDL gamepad when available', () async {
    if (!VigemController.runtimeInfo.available) {
      return;
    }
    final devices = SdlInput.enumerateGamepads();
    if (devices.isEmpty) {
      return;
    }
    final device = devices.firstWhere(
      (candidate) => candidate.isRogAllyX,
      orElse: () => devices.first,
    );
    final portProbe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = portProbe.port;
    await portProbe.close();

    final server = LanController.createServer(port: port);
    final client = LanController.createClient(
      instanceId: device.instanceId,
      serverAddress: InternetAddress.loopbackIPv4.address,
      port: port,
      pairingKey: LanController.pairingCode(),
    );
    addTearDown(server.close);
    addTearDown(client.close);
    server.start();
    client.start();

    final connectedClient = await _waitForLanClient(
      client,
      (snapshot) => snapshot.connected && snapshot.sentPacketCount > 0,
    );
    expect(connectedClient.state, LanSessionState.running);
    final connectedServer = await _waitForLan(
      server,
      (snapshot) => snapshot.connected && snapshot.receivedPacketCount > 0,
    );
    expect(connectedServer.state, LanSessionState.running);
    expect(connectedServer.latestSequence, greaterThan(0));
  });

  test('pairing code persists within the store and regenerates on demand', () {
    final first = LanController.pairingCode();
    expect(first, inInclusiveRange(0, 9999));
    expect(LanController.pairingCode(), first);
    final regenerated = LanController.regeneratePairingCode();
    expect(regenerated, inInclusiveRange(0, 9999));
    expect(LanController.pairingCode(), regenerated);
  });

  test('server rejects a wrong pairing key and keeps listening', () async {
    if (!VigemController.runtimeInfo.available) {
      return;
    }
    final portProbe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = portProbe.port;
    await portProbe.close();

    final code = LanController.pairingCode();
    final server = LanController.createServer(
      port: port,
      inputTimeout: const Duration(milliseconds: 80),
    );
    addTearDown(server.close);
    server.start();

    final wrong = await _connectControl(port);
    addTearDown(wrong.destroy);
    wrong.add(
      _controlFrame(
        type: 1,
        sessionId: 0xAAAA0001,
        pairingKey: (code + 1) % 10000,
      ),
    );
    await wrong.flush();
    final rejection = await _readBytes(wrong, 32);
    final rejectionView = ByteData.sublistView(rejection);
    expect(rejectionView.getUint8(5), 6); // ControlMessageType::kError
    expect(rejectionView.getUint64(16, Endian.little), 1); // mismatch reason
    expect(server.snapshot().state, LanSessionState.running);
    wrong.destroy();

    final ok = await _connectControl(port);
    addTearDown(ok.destroy);
    ok.add(_controlFrame(type: 1, sessionId: 0xBBBB0002, pairingKey: code));
    await ok.flush();
    final ack = await _readBytes(ok, 32);
    expect(ByteData.sublistView(ack).getUint8(5), 2); // kHelloAck
  });
}

Future<Socket> _connectControl(int port) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (DateTime.now().isBefore(deadline)) {
    try {
      return await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(milliseconds: 200),
      );
    } on SocketException {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }
  throw TestFailure('Could not connect to the LAN control port.');
}

Uint8List _controlFrame({
  required int type,
  required int sessionId,
  int pairingKey = 0,
}) {
  final data = ByteData(32)
    ..setUint32(0, 0x31434352, Endian.little)
    ..setUint8(4, 1)
    ..setUint8(5, type)
    ..setUint16(6, 0, Endian.little)
    ..setUint16(8, 32, Endian.little)
    ..setUint16(10, pairingKey, Endian.little)
    ..setUint32(12, sessionId, Endian.little);
  return data.buffer.asUint8List();
}

Uint8List _inputPacket({required int sessionId}) {
  final data = ByteData(64)
    ..setUint32(0, 0x31494352, Endian.little)
    ..setUint8(4, 1)
    ..setUint8(5, 1)
    ..setUint16(6, 1, Endian.little)
    ..setUint16(8, 64, Endian.little)
    ..setUint16(10, 32, Endian.little)
    ..setUint32(12, sessionId, Endian.little)
    ..setUint64(16, 7, Endian.little)
    ..setUint64(24, 123456789, Endian.little)
    ..setUint32(32, GamepadButton.a, Endian.little)
    ..setUint16(36, 65535, Endian.little)
    ..setUint16(38, 32768, Endian.little)
    ..setInt16(40, -32768, Endian.little)
    ..setInt16(42, 32767, Endian.little)
    ..setInt16(44, -1234, Endian.little)
    ..setInt16(46, 4321, Endian.little);
  return data.buffer.asUint8List();
}

Future<Uint8List> _readBytes(Socket socket, int count) async {
  final builder = BytesBuilder(copy: false);
  final completer = Completer<Uint8List>();
  socket.listen(
    (chunk) {
      if (completer.isCompleted) {
        return;
      }
      builder.add(chunk);
      if (builder.length >= count) {
        final bytes = builder.takeBytes();
        completer.complete(Uint8List.sublistView(bytes, 0, count));
      }
    },
    onError: completer.completeError,
    onDone: () {
      if (!completer.isCompleted) {
        completer.completeError(
          TestFailure('The control socket closed before $count bytes arrived.'),
        );
      }
    },
  );
  return completer.future.timeout(const Duration(seconds: 2));
}

Future<LanSessionSnapshot> _waitForLan(
  LanControllerServer server,
  bool Function(LanSessionSnapshot snapshot) predicate,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (DateTime.now().isBefore(deadline)) {
    final snapshot = server.snapshot();
    if (predicate(snapshot)) {
      return snapshot;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw TestFailure('Timed out waiting for LAN session state.');
}

Future<LanSessionSnapshot> _waitForLanClient(
  LanControllerClient client,
  bool Function(LanSessionSnapshot snapshot) predicate,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (DateTime.now().isBefore(deadline)) {
    final snapshot = client.snapshot();
    if (predicate(snapshot)) {
      return snapshot;
    }
    if (snapshot.state == LanSessionState.faulted ||
        snapshot.state == LanSessionState.disconnected) {
      throw TestFailure(
        'LAN client failed: ${snapshot.error} (${snapshot.lastError}).',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw TestFailure('Timed out waiting for LAN client state.');
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
