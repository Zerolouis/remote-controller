// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

abstract final class GamepadButton {
  static const int dpadUp = 0x0001;
  static const int dpadDown = 0x0002;
  static const int dpadLeft = 0x0004;
  static const int dpadRight = 0x0008;
  static const int start = 0x0010;
  static const int back = 0x0020;
  static const int leftStick = 0x0040;
  static const int rightStick = 0x0080;
  static const int leftShoulder = 0x0100;
  static const int rightShoulder = 0x0200;
  static const int guide = 0x0400;
  static const int a = 0x1000;
  static const int b = 0x2000;
  static const int x = 0x4000;
  static const int y = 0x8000;
}

final class GamepadState {
  const GamepadState({
    required this.buttonFlags,
    required this.leftTrigger,
    required this.rightTrigger,
    required this.leftStickX,
    required this.leftStickY,
    required this.rightStickX,
    required this.rightStickY,
  }) : assert(buttonFlags >= 0 && buttonFlags <= 0xffffffff),
       assert(leftTrigger >= 0 && leftTrigger <= 0xffff),
       assert(rightTrigger >= 0 && rightTrigger <= 0xffff),
       assert(leftStickX >= -0x8000 && leftStickX <= 0x7fff),
       assert(leftStickY >= -0x8000 && leftStickY <= 0x7fff),
       assert(rightStickX >= -0x8000 && rightStickX <= 0x7fff),
       assert(rightStickY >= -0x8000 && rightStickY <= 0x7fff);

  static const neutral = GamepadState(
    buttonFlags: 0,
    leftTrigger: 0,
    rightTrigger: 0,
    leftStickX: 0,
    leftStickY: 0,
    rightStickX: 0,
    rightStickY: 0,
  );

  final int buttonFlags;
  final int leftTrigger;
  final int rightTrigger;
  final int leftStickX;
  final int leftStickY;
  final int rightStickX;
  final int rightStickY;

  bool isPressed(int button) => buttonFlags & button != 0;

  GamepadState withButton(int button, {required bool pressed}) {
    final nextFlags = pressed ? buttonFlags | button : buttonFlags & ~button;
    return GamepadState(
      buttonFlags: nextFlags,
      leftTrigger: leftTrigger,
      rightTrigger: rightTrigger,
      leftStickX: leftStickX,
      leftStickY: leftStickY,
      rightStickX: rightStickX,
      rightStickY: rightStickY,
    );
  }
}
