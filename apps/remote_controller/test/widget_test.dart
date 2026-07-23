// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_controller/app.dart';
import 'package:remote_controller/data/repositories/core_repository.dart';
import 'package:remote_controller/domain/models/core_info.dart';
import 'package:remote_controller/domain/models/input_capture_snapshot.dart';
import 'package:remote_controller/domain/models/input_device.dart';
import 'package:remote_controller/domain/models/loopback_diagnostic.dart';
import 'package:remote_controller/domain/models/virtual_controller.dart';

void main() {
  testWidgets('shows healthy native core and both roles', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(RemoteControllerApp(coreRepository: _FakeCoreRepository()));
    await tester.pump();

    expect(find.text('Windows 原生核心已加载 · ABI 1'), findsOneWidget);
    expect(find.text('掌机客户端'), findsOneWidget);
    expect(find.text('电脑服务端'), findsOneWidget);
  });

  testWidgets('selects server role and returns to role selection', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(RemoteControllerApp(coreRepository: _FakeCoreRepository()));
    await tester.tap(find.byKey(const Key('server-role')));
    await tester.pump();

    expect(find.text('检查驱动'), findsOneWidget);
    expect(find.text('启动服务（待实现）'), findsOneWidget);

    await tester.tap(find.byKey(const Key('back-to-roles')));
    await tester.pump();

    expect(find.byKey(const Key('client-role')), findsOneWidget);
  });

  testWidgets('runs native loopback diagnostic from role dashboard', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(RemoteControllerApp(coreRepository: _FakeCoreRepository()));
    await tester.tap(find.byKey(const Key('client-role')));
    await tester.pump();

    expect(find.textContaining('尚未运行'), findsOneWidget);
    await tester.tap(find.byKey(const Key('run-loopback-diagnostic')));
    await tester.pumpAndSettle();

    expect(find.textContaining('自检通过'), findsOneWidget);
    expect(find.textContaining('1 次安全归零'), findsOneWidget);
  });

  testWidgets('shows ROG Ally X and raw native capture values', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      RemoteControllerApp(coreRepository: _FakeCoreRepository()),
    );
    await tester.tap(find.byKey(const Key('client-role')));
    await tester.pumpAndSettle();

    expect(find.text('SDL 3.4.12 · 原生 250 Hz 采样，界面仅显示 10 Hz 快照'), findsOneWidget);
    expect(find.text('ROG Ally X'), findsOneWidget);
    expect(find.textContaining('VID 0B05 · PID 1B4C'), findsOneWidget);

    await tester.tap(find.byKey(const Key('capture-device-42')));
    await tester.pump();

    expect(find.textContaining('250 个原生样本'), findsOneWidget);
    expect(find.text('65535'), findsOneWidget);
    expect(find.textContaining('LT 0..65535'), findsOneWidget);
    expect(find.textContaining('LX -32768..32767'), findsOneWidget);

    await tester.tap(find.byKey(const Key('stop-input-capture')));
    await tester.pump();
    expect(find.byKey(const Key('input-capture-status')), findsNothing);
  });

  testWidgets('shows an available ViGEmBus on the server dashboard', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      RemoteControllerApp(coreRepository: _FakeCoreRepository()),
    );
    await tester.tap(find.byKey(const Key('server-role')));
    await tester.pump();

    expect(find.text('ViGEm 虚拟 Xbox 360 后端'), findsOneWidget);
    expect(
      find.text('ViGEmBus 已连接，可创建单个 X360 target 并接收双马达震动。'),
      findsOneWidget,
    );
  });

  testWidgets('starts and stops the local SDL to ViGEm bridge', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      RemoteControllerApp(coreRepository: _FakeCoreRepository()),
    );
    await tester.tap(find.byKey(const Key('client-role')));
    await tester.pumpAndSettle();

    final startButton = find.byKey(const Key('bridge-device-42'));
    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pump();

    expect(find.byKey(const Key('stop-local-bridge')), findsOneWidget);
    expect(find.textContaining('本机 SDL → ViGEm · 500 个样本'), findsOneWidget);
    expect(find.text('65535'), findsOneWidget);
    expect(find.textContaining('震动回调 3 次'), findsOneWidget);
    expect(find.textContaining('低频 65535 · 高频 32768'), findsOneWidget);
    expect(find.textContaining('HidHide 尚未启用'), findsOneWidget);

    await tester.tap(find.byKey(const Key('stop-local-bridge')));
    await tester.pump();

    expect(find.byKey(const Key('local-bridge-status')), findsNothing);
    expect(find.byKey(const Key('bridge-device-42')), findsOneWidget);
  });

  testWidgets('downloads ViGEmBus and refreshes driver availability', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeCoreRepository(vigemAvailable: false);

    await tester.pumpWidget(RemoteControllerApp(coreRepository: repository));
    await tester.tap(find.byKey(const Key('server-role')));
    await tester.pump();

    expect(find.byKey(const Key('install-vigem-server')), findsOneWidget);
    expect(find.textContaining('校验固定 SHA-256'), findsOneWidget);

    await tester.tap(find.byKey(const Key('install-vigem-server')));
    await tester.pumpAndSettle();

    expect(repository.installCallCount, 1);
    expect(find.textContaining('安装器已启动'), findsOneWidget);

    repository.vigemAvailable = true;
    await tester.tap(find.byKey(const Key('refresh-vigem-server')));
    await tester.pump();

    expect(find.textContaining('ViGEmBus 已连接'), findsOneWidget);
    expect(find.text('ViGEmBus 已可用。'), findsOneWidget);
    expect(find.byKey(const Key('install-vigem-server')), findsNothing);
  });
}

final class _FakeCoreRepository implements CoreRepository {
  _FakeCoreRepository({this.vigemAvailable = true});

  bool vigemAvailable;
  int installCallCount = 0;

  @override
  CoreInfo getCoreInfo() => const CoreInfo(
    abiVersion: 1,
    buildInfo: 'remote-controller-core/test',
  );

  @override
  Future<LoopbackDiagnostic> runLoopbackDiagnostic() async => const LoopbackDiagnostic(
    acceptedStateCount: 1,
    neutralizationCount: 1,
    elapsedMilliseconds: 50,
  );

  @override
  InputRuntime getInputRuntime() => const InputRuntime(
    available: true,
    version: '3.4.12',
    revision: 'test',
    error: '',
  );

  @override
  VirtualControllerRuntime getVirtualControllerRuntime() => VirtualControllerRuntime(
    available: vigemAvailable,
    resultCode: vigemAvailable ? 0 : 0xe0000001,
    error: vigemAvailable ? '' : 'ViGEmBus driver was not found.',
  );

  @override
  Future<VigemBusInstallResult> installVigemBus() async {
    installCallCount += 1;
    return VigemBusInstallResult(
      version: '1.22.0',
      sourceUrl: Uri.parse(
        'https://github.com/nefarius/ViGEmBus/releases/tag/v1.22.0',
      ),
    );
  }

  @override
  Future<List<InputDevice>> enumerateInputDevices() async => const [
    InputDevice(
      instanceId: 42,
      name: 'ASUS ROG Ally X Gamepad',
      path: r'\\?\HID#VID_0B05&PID_1B4C',
      guid: '03000000050b00004c1b000000000000',
      vendorId: 0x0b05,
      productId: 0x1b4c,
      productVersion: 1,
      gamepadType: 1,
      connectionState: 1,
      capabilities: 3,
      supportedButtons: 0xffff,
      isRogAllyX: true,
      supportsAnalogTriggers: true,
      supportsRumble: true,
    ),
  ];

  @override
  void startInputCapture(int instanceId) {}

  @override
  InputCaptureSnapshot getInputCaptureSnapshot() => const InputCaptureSnapshot(
    state: 'running',
    sampleCount: 250,
    buttonFlags: 0x1000,
    leftTrigger: 65535,
    rightTrigger: 32768,
    leftStickX: -32768,
    leftStickY: 32767,
    rightStickX: -1234,
    rightStickY: 4321,
    observedButtonFlags: 0x1000,
    leftTriggerMax: 65535,
    rightTriggerMax: 32768,
    leftStickXMin: -32768,
    leftStickXMax: 32767,
    leftStickYMin: -32000,
    leftStickYMax: 32000,
    rightStickXMin: -12000,
    rightStickXMax: 12000,
    rightStickYMin: -13000,
    rightStickYMax: 13000,
  );

  @override
  void stopInputCapture() {}

  @override
  void startLocalBridge(int instanceId) {}

  @override
  LocalBridgeSnapshot getLocalBridgeSnapshot() => const LocalBridgeSnapshot(
    state: 'running',
    sampleCount: 500,
    buttonFlags: 0x1000,
    leftTrigger: 65535,
    rightTrigger: 32768,
    leftStickX: -32768,
    leftStickY: 32767,
    rightStickX: -1234,
    rightStickY: 4321,
    rumbleCount: 3,
    lowFrequencyMotor: 65535,
    highFrequencyMotor: 32768,
  );

  @override
  void stopLocalBridge() {}

  @override
  void dispose() {}
}
