// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'package:native_toolchain_c/native_toolchain_c.dart';

const remoteControllerAssetName = 'src/third_party/remote_controller_core.g.dart';

final remoteControllerLibrary = CLibrary(
  name: 'remote_controller_core',
  assetName: remoteControllerAssetName,
  sources: const ['native/src/remote_controller_core.cpp'],
  includes: const ['native/include'],
  language: Language.cpp,
  std: 'c++20',
);

// native_toolchain_c 0.19.2 forwards the C++ `/TP` compile flag to MSVC's
// archive link invocation. A dedicated linker spec avoids treating `.lib`
// archives as C++ source files while preserving C++ compilation above.
final remoteControllerLinker = CLinker.library(
  name: 'remote_controller_core',
  assetName: remoteControllerAssetName,
);
