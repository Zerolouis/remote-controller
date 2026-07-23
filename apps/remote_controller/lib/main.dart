// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'package:flutter/widgets.dart';
import 'package:remote_controller/app.dart';
import 'package:remote_controller/data/repositories/native_core_repository.dart';
import 'package:remote_controller/data/services/native_core_service.dart';
import 'package:remote_controller/data/services/vigem_installer_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    RemoteControllerApp(
      coreRepository: NativeCoreRepository(
        NativeCoreService(),
        VigemInstallerService(),
      ),
    ),
  );
}
