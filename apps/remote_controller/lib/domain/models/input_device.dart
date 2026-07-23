// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

final class InputRuntime {
  const InputRuntime({
    required this.available,
    required this.version,
    required this.revision,
    required this.error,
  });

  final bool available;
  final String version;
  final String revision;
  final String error;
}

final class InputDevice {
  const InputDevice({
    required this.instanceId,
    required this.name,
    required this.path,
    required this.guid,
    required this.vendorId,
    required this.productId,
    required this.productVersion,
    required this.gamepadType,
    required this.connectionState,
    required this.capabilities,
    required this.supportedButtons,
    required this.isRogAllyX,
    required this.supportsAnalogTriggers,
    required this.supportsRumble,
  });

  final int instanceId;
  final String name;
  final String path;
  final String guid;
  final int vendorId;
  final int productId;
  final int productVersion;
  final int gamepadType;
  final int connectionState;
  final int capabilities;
  final int supportedButtons;
  final bool isRogAllyX;
  final bool supportsAnalogTriggers;
  final bool supportsRumble;
}
