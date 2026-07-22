// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'package:remote_controller/domain/models/core_info.dart';

abstract interface class CoreRepository {
  CoreInfo getCoreInfo();
}
