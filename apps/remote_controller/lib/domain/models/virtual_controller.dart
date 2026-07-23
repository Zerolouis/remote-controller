// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

final class VirtualControllerRuntime {
  const VirtualControllerRuntime({
    required this.available,
    required this.resultCode,
    required this.error,
  });

  final bool available;
  final int resultCode;
  final String error;
}

final class LocalBridgeSnapshot {
  const LocalBridgeSnapshot({
    required this.state,
    required this.sampleCount,
    required this.buttonFlags,
    required this.leftTrigger,
    required this.rightTrigger,
    required this.leftStickX,
    required this.leftStickY,
    required this.rightStickX,
    required this.rightStickY,
    required this.rumbleCount,
    required this.lowFrequencyMotor,
    required this.highFrequencyMotor,
  });

  final String state;
  final int sampleCount;
  final int buttonFlags;
  final int leftTrigger;
  final int rightTrigger;
  final int leftStickX;
  final int leftStickY;
  final int rightStickX;
  final int rightStickY;
  final int rumbleCount;
  final int lowFrequencyMotor;
  final int highFrequencyMotor;
}
