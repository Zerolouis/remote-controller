// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'package:remote_controller/data/repositories/core_repository.dart';
import 'package:remote_controller/data/services/native_core_service.dart';
import 'package:remote_controller/domain/models/core_info.dart';
import 'package:remote_controller/domain/models/loopback_diagnostic.dart';

final class NativeCoreRepository implements CoreRepository {
  const NativeCoreRepository(this._service);

  final NativeCoreService _service;

  @override
  CoreInfo getCoreInfo() => CoreInfo(
    abiVersion: _service.getAbiVersion(),
    buildInfo: _service.getBuildInfo(),
  );

  @override
  Future<LoopbackDiagnostic> runLoopbackDiagnostic() async {
    final result = await _service.runLoopbackDiagnostic();
    return LoopbackDiagnostic(
      acceptedStateCount: result.acceptedStateCount,
      neutralizationCount: result.neutralizationCount,
      elapsedMilliseconds: result.elapsedMilliseconds,
    );
  }
}
