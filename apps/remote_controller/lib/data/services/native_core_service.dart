// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'package:remote_controller_core/remote_controller_core.dart';

final class NativeCoreService {
  int getAbiVersion() => RemoteControllerCore.abiVersion;

  String getBuildInfo() => RemoteControllerCore.buildInfo;
}
