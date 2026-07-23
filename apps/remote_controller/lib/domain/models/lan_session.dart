// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

final class LanSessionStatus {
  const LanSessionStatus({
    required this.state,
    required this.connected,
    required this.sentPacketCount,
    required this.receivedPacketCount,
    required this.droppedPacketCount,
    required this.neutralizationCount,
    required this.latestSequence,
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
    required this.peerAddress,
    required this.lastError,
    required this.error,
    required this.pairingKeyMismatch,
  });

  final String state;
  final bool connected;
  final int sentPacketCount;
  final int receivedPacketCount;
  final int droppedPacketCount;
  final int neutralizationCount;
  final int latestSequence;
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
  final String peerAddress;
  final int lastError;
  final String error;
  final bool pairingKeyMismatch;
}
