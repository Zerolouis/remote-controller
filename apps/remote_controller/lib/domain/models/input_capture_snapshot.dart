// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

final class InputCaptureSnapshot {
  const InputCaptureSnapshot({
    required this.state,
    required this.sampleCount,
    required this.buttonFlags,
    required this.leftTrigger,
    required this.rightTrigger,
    required this.leftStickX,
    required this.leftStickY,
    required this.rightStickX,
    required this.rightStickY,
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

  final String state;
  final int sampleCount;
  final int buttonFlags;
  final int leftTrigger;
  final int rightTrigger;
  final int leftStickX;
  final int leftStickY;
  final int rightStickX;
  final int rightStickY;
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
