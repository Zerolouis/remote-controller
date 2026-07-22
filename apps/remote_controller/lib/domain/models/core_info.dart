// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

final class CoreInfo {
  const CoreInfo({required this.abiVersion, required this.buildInfo});

  final int abiVersion;
  final String buildInfo;
}
