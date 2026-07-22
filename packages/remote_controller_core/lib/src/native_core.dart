// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'package:ffi/ffi.dart';
import 'package:remote_controller_core/src/third_party/remote_controller_core.g.dart' as native;

abstract final class RemoteControllerCore {
  static int get abiVersion => native.rc_get_abi_version();

  static String get buildInfo => native.rc_get_build_info().cast<Utf8>().toDartString();
}
