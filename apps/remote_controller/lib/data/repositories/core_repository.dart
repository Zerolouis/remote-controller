// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'package:remote_controller/domain/models/core_info.dart';
import 'package:remote_controller/domain/models/input_capture_snapshot.dart';
import 'package:remote_controller/domain/models/input_device.dart';
import 'package:remote_controller/domain/models/loopback_diagnostic.dart';

abstract interface class CoreRepository {
  CoreInfo getCoreInfo();

  Future<LoopbackDiagnostic> runLoopbackDiagnostic();

  InputRuntime getInputRuntime();

  Future<List<InputDevice>> enumerateInputDevices();

  void startInputCapture(int instanceId);

  InputCaptureSnapshot getInputCaptureSnapshot();

  void stopInputCapture();

  void dispose();
}
