// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:remote_controller_core/src/c_library.dart';
import 'package:remote_controller_core/src/sdl_dependency.dart';

Future<void> main(List<String> arguments) async {
  await build(arguments, (input, output) async {
    if (!input.config.buildCodeAssets) {
      return;
    }

    if (input.config.code.targetOS != OS.windows) {
      throw UnsupportedError(
        'Remote Controller currently supports Windows only.',
      );
    }

    final sdlSdk = await prepareSdlSdk(
      outputDirectory: input.outputDirectory,
      targetArchitecture: input.config.code.targetArchitecture,
      localSdkPath: input.userDefines['sdl_sdk_path'] as String?,
    );
    final remoteControllerLibrary = createRemoteControllerLibrary(
      sdlIncludeDirectory: sdlSdk.includeDirectory.path,
    );

    await remoteControllerLibrary.build(
      input: input,
      output: output,
      defines: <String, String?>{
        if (input.config.code.targetOS == OS.windows) 'RC_BUILDING_DLL': '1',
      },
    );

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: sdlRuntimeAssetName,
        linkMode: DynamicLoadingBundled(),
        file: sdlSdk.runtimeLibrary.uri,
      ),
    );
    output.dependencies.add(sdlSdk.runtimeLibrary.uri);
  });
}
