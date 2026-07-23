// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

final class VigemInstallerData {
  const VigemInstallerData({
    required this.version,
    required this.sourceUrl,
    required this.installerPath,
  });

  final String version;
  final Uri sourceUrl;
  final String installerPath;
}
