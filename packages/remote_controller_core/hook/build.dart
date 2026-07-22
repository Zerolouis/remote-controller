// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:remote_controller_core/src/c_library.dart';

Future<void> main(List<String> arguments) async {
  await build(arguments, (input, output) async {
    if (!input.config.buildCodeAssets) {
      return;
    }

    await remoteControllerLibrary.build(
      input: input,
      output: output,
      defines: <String, String?>{
        if (input.config.code.targetOS == OS.windows) 'RC_BUILDING_DLL': '1',
      },
    );
  });
}
