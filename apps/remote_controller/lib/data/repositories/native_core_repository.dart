// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'package:remote_controller/data/repositories/core_repository.dart';
import 'package:remote_controller/data/services/native_core_service.dart';
import 'package:remote_controller/data/services/vigem_installer_service.dart';
import 'package:remote_controller/domain/models/core_info.dart';
import 'package:remote_controller/domain/models/input_capture_snapshot.dart';
import 'package:remote_controller/domain/models/input_device.dart';
import 'package:remote_controller/domain/models/lan_session.dart';
import 'package:remote_controller/domain/models/loopback_diagnostic.dart';
import 'package:remote_controller/domain/models/virtual_controller.dart' as domain;
import 'package:remote_controller_core/remote_controller_core.dart';

final class NativeCoreRepository implements CoreRepository {
  const NativeCoreRepository(this._service, this._vigemInstallerService);

  final NativeCoreService _service;
  final VigemInstallerService _vigemInstallerService;

  @override
  CoreInfo getCoreInfo() => CoreInfo(
    abiVersion: _service.getAbiVersion(),
    buildInfo: _service.getBuildInfo(),
  );

  @override
  Future<LoopbackDiagnostic> runLoopbackDiagnostic() async {
    final result = await _service.runLoopbackDiagnostic();
    return LoopbackDiagnostic(
      acceptedStateCount: result.acceptedStateCount,
      neutralizationCount: result.neutralizationCount,
      elapsedMilliseconds: result.elapsedMilliseconds,
    );
  }

  @override
  InputRuntime getInputRuntime() {
    final runtime = _service.getInputRuntime();
    return InputRuntime(
      available: runtime.available,
      version: runtime.versionLabel,
      revision: runtime.revision,
      error: runtime.error,
    );
  }

  @override
  Future<List<InputDevice>> enumerateInputDevices() async => _service
      .enumerateInputDevices()
      .map(
        (device) => InputDevice(
          instanceId: device.instanceId,
          name: device.name,
          path: device.path,
          guid: device.guid,
          vendorId: device.vendorId,
          productId: device.productId,
          productVersion: device.productVersion,
          gamepadType: device.gamepadType,
          connectionState: device.connectionState,
          capabilities: device.capabilities,
          supportedButtons: device.supportedButtons,
          isRogAllyX: device.isRogAllyX,
          supportsAnalogTriggers: device.hasCapability(
            InputCapability.analogTriggers,
          ),
          supportsRumble: device.hasCapability(InputCapability.rumble),
        ),
      )
      .toList(growable: false);

  @override
  domain.VirtualControllerRuntime getVirtualControllerRuntime() {
    final runtime = _service.getVirtualControllerRuntime();
    return domain.VirtualControllerRuntime(
      available: runtime.available,
      resultCode: runtime.resultCode,
      error: runtime.error,
    );
  }

  @override
  Future<domain.VigemBusInstallResult> installVigemBus() async {
    final result = await _vigemInstallerService.downloadAndLaunch();
    return domain.VigemBusInstallResult(
      version: result.version,
      sourceUrl: result.sourceUrl,
    );
  }

  @override
  void startInputCapture(int instanceId) => _service.startInputCapture(instanceId);

  @override
  InputCaptureSnapshot getInputCaptureSnapshot() {
    final snapshot = _service.getInputCaptureSnapshot();
    final state = snapshot.currentState;
    return InputCaptureSnapshot(
      state: snapshot.state.name,
      sampleCount: snapshot.sampleCount,
      buttonFlags: state.buttonFlags,
      leftTrigger: state.leftTrigger,
      rightTrigger: state.rightTrigger,
      leftStickX: state.leftStickX,
      leftStickY: state.leftStickY,
      rightStickX: state.rightStickX,
      rightStickY: state.rightStickY,
      observedButtonFlags: snapshot.observedButtonFlags,
      leftTriggerMax: snapshot.leftTriggerMax,
      rightTriggerMax: snapshot.rightTriggerMax,
      leftStickXMin: snapshot.leftStickXMin,
      leftStickXMax: snapshot.leftStickXMax,
      leftStickYMin: snapshot.leftStickYMin,
      leftStickYMax: snapshot.leftStickYMax,
      rightStickXMin: snapshot.rightStickXMin,
      rightStickXMax: snapshot.rightStickXMax,
      rightStickYMin: snapshot.rightStickYMin,
      rightStickYMax: snapshot.rightStickYMax,
    );
  }

  @override
  void stopInputCapture() => _service.stopInputCapture();

  @override
  void startLocalBridge(int instanceId) => _service.startLocalBridge(instanceId);

  @override
  domain.LocalBridgeSnapshot getLocalBridgeSnapshot() {
    final snapshot = _service.getLocalBridgeSnapshot();
    final state = snapshot.currentState;
    return domain.LocalBridgeSnapshot(
      state: snapshot.state.name,
      sampleCount: snapshot.sampleCount,
      buttonFlags: state.buttonFlags,
      leftTrigger: state.leftTrigger,
      rightTrigger: state.rightTrigger,
      leftStickX: state.leftStickX,
      leftStickY: state.leftStickY,
      rightStickX: state.rightStickX,
      rightStickY: state.rightStickY,
      rumbleCount: snapshot.rumbleCount,
      lowFrequencyMotor: snapshot.lowFrequencyMotor,
      highFrequencyMotor: snapshot.highFrequencyMotor,
    );
  }

  @override
  void stopLocalBridge() => _service.stopLocalBridge();

  @override
  void startLanClient(int instanceId, String serverAddress, {int pairingKey = 0}) =>
      _service.startLanClient(instanceId, serverAddress, pairingKey: pairingKey);

  @override
  LanSessionStatus getLanClientStatus() => _mapLanSession(_service.getLanClientStatus());

  @override
  void stopLanClient() => _service.stopLanClient();

  @override
  void startLanServer() => _service.startLanServer();

  @override
  LanSessionStatus getLanServerStatus() => _mapLanSession(_service.getLanServerStatus());

  @override
  void stopLanServer() => _service.stopLanServer();

  @override
  int pairingCode() => _service.pairingCode();

  @override
  int regeneratePairingCode() => _service.regeneratePairingCode();

  @override
  void dispose() => _service.dispose();

  LanSessionStatus _mapLanSession(LanSessionSnapshot snapshot) {
    final state = snapshot.currentState;
    return LanSessionStatus(
      state: snapshot.state.name,
      connected: snapshot.connected,
      sentPacketCount: snapshot.sentPacketCount,
      receivedPacketCount: snapshot.receivedPacketCount,
      droppedPacketCount: snapshot.droppedPacketCount,
      neutralizationCount: snapshot.neutralizationCount,
      latestSequence: snapshot.latestSequence,
      buttonFlags: state.buttonFlags,
      leftTrigger: state.leftTrigger,
      rightTrigger: state.rightTrigger,
      leftStickX: state.leftStickX,
      leftStickY: state.leftStickY,
      rightStickX: state.rightStickX,
      rightStickY: state.rightStickY,
      rumbleCount: snapshot.rumbleCount,
      lowFrequencyMotor: snapshot.lowFrequencyMotor,
      highFrequencyMotor: snapshot.highFrequencyMotor,
      peerAddress: snapshot.peerAddress,
      lastError: snapshot.lastError,
      error: snapshot.error,
      pairingKeyMismatch: snapshot.pairingKeyMismatch,
    );
  }
}
