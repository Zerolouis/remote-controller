// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'package:flutter_test/flutter_test.dart';
import 'package:remote_controller_core/remote_controller_core.dart';

void main() {
  test('generated FFI bindings call the Native Assets library', () {
    expect(RemoteControllerCore.abiVersion, 1);
    expect(RemoteControllerCore.buildInfo, contains('protocol=1'));
    expect(RemoteControllerCore.buildInfo, contains('vigem-x360'));
    expect(RemoteControllerCore.buildInfo, contains('vigem-installer-launch'));
    expect(SdlInput.runtimeInfo.versionLabel, '3.4.12');
  });
}
