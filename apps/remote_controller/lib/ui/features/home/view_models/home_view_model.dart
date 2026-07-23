// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'package:flutter/foundation.dart';
import 'package:remote_controller/data/repositories/core_repository.dart';
import 'package:remote_controller/domain/models/app_role.dart';
import 'package:remote_controller/domain/models/core_info.dart';
import 'package:remote_controller/domain/models/loopback_diagnostic.dart';

final class HomeViewModel extends ChangeNotifier {
  HomeViewModel(this._coreRepository);

  final CoreRepository _coreRepository;

  CoreInfo? _coreInfo;
  Object? _coreError;
  AppRole? _selectedRole;
  bool _isRunningDiagnostic = false;
  LoopbackDiagnostic? _diagnostic;
  Object? _diagnosticError;

  CoreInfo? get coreInfo => _coreInfo;
  Object? get coreError => _coreError;
  AppRole? get selectedRole => _selectedRole;
  bool get isRunningDiagnostic => _isRunningDiagnostic;
  LoopbackDiagnostic? get diagnostic => _diagnostic;
  Object? get diagnosticError => _diagnosticError;

  void initialize() {
    try {
      _coreInfo = _coreRepository.getCoreInfo();
      _coreError = null;
    } on Object catch (error) {
      _coreInfo = null;
      _coreError = error;
    }
    notifyListeners();
  }

  void selectRole(AppRole role) {
    if (_selectedRole == role) {
      return;
    }
    _selectedRole = role;
    notifyListeners();
  }

  void clearRole() {
    if (_selectedRole == null) {
      return;
    }
    _selectedRole = null;
    notifyListeners();
  }

  Future<void> runLoopbackDiagnostic() async {
    if (_isRunningDiagnostic) {
      return;
    }
    _isRunningDiagnostic = true;
    _diagnostic = null;
    _diagnosticError = null;
    notifyListeners();

    try {
      _diagnostic = await _coreRepository.runLoopbackDiagnostic();
    } on Object catch (error) {
      _diagnosticError = error;
    } finally {
      _isRunningDiagnostic = false;
      notifyListeners();
    }
  }
}
