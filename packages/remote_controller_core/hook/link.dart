// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

// ignore_for_file: experimental_member_use

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:record_use/record_use.dart';
import 'package:remote_controller_core/src/c_library.dart';
import 'package:remote_controller_core/src/third_party/remote_controller_core.record_use_mapping.g.dart';

Future<void> main(List<String> arguments) async {
  await link(arguments, (input, output) async {
    final symbols = input.recordedUses?.calls.keys
        .whereType<Method>()
        .map((method) => remoteControllerRecordUseMapping[method.name])
        .whereType<String>()
        .toSet();

    final sources = input.assets.code
        .where((asset) => asset.id.endsWith(remoteControllerAssetName))
        .map((asset) => asset.file!.toFilePath())
        .toList(growable: false);

    await remoteControllerLinker.run(
      input: input,
      output: output,
      sources: sources,
      linkerOptions: LinkerOptions.treeshake(symbolsToKeep: symbols),
    );
  });
}
