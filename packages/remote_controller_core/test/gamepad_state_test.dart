// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'package:remote_controller_core/remote_controller_core.dart';
import 'package:test/test.dart';

void main() {
  group('GamepadState', () {
    test('neutral state has no active controls', () {
      expect(GamepadState.neutral.buttonFlags, 0);
      expect(GamepadState.neutral.leftTrigger, 0);
      expect(GamepadState.neutral.rightTrigger, 0);
      expect(GamepadState.neutral.leftStickX, 0);
      expect(GamepadState.neutral.isPressed(GamepadButton.a), isFalse);
    });

    test('button updates preserve raw axes and triggers', () {
      const state = GamepadState(
        buttonFlags: GamepadButton.leftShoulder,
        leftTrigger: 65535,
        rightTrigger: 12345,
        leftStickX: -32768,
        leftStickY: 32767,
        rightStickX: -12,
        rightStickY: 42,
      );

      final updated = state.withButton(GamepadButton.a, pressed: true);

      expect(updated.isPressed(GamepadButton.a), isTrue);
      expect(updated.isPressed(GamepadButton.leftShoulder), isTrue);
      expect(updated.leftTrigger, 65535);
      expect(updated.leftStickX, -32768);
      expect(updated.leftStickY, 32767);
    });
  });
}
