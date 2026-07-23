// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'package:remote_controller/data/repositories/core_repository.dart';
import 'package:remote_controller/data/services/native_core_service.dart';
import 'package:remote_controller/domain/models/core_info.dart';
import 'package:remote_controller/domain/models/input_capture_snapshot.dart';
import 'package:remote_controller/domain/models/input_device.dart';
import 'package:remote_controller/domain/models/loopback_diagnostic.dart';
import 'package:remote_controller/domain/models/virtual_controller.dart' as domain;
import 'package:remote_controller_core/remote_controller_core.dart';

final class NativeCoreRepository implements CoreRepository {
  const NativeCoreRepository(this._service);

  final NativeCoreService _service;

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
  void dispose() => _service.dispose();
}
