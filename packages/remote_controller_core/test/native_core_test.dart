// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'package:remote_controller_core/remote_controller_core.dart';
import 'package:test/test.dart';

void main() {
  test('native smoke ABI is available through generated bindings', () {
    expect(RemoteControllerCore.abiVersion, 1);
    expect(RemoteControllerCore.buildInfo, contains('protocol=1'));
  });
}
