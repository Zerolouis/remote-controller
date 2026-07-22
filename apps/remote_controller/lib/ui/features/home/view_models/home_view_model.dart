// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'package:flutter/foundation.dart';
import 'package:remote_controller/data/repositories/core_repository.dart';
import 'package:remote_controller/domain/models/app_role.dart';
import 'package:remote_controller/domain/models/core_info.dart';

final class HomeViewModel extends ChangeNotifier {
  HomeViewModel(this._coreRepository);

  final CoreRepository _coreRepository;

  CoreInfo? _coreInfo;
  Object? _coreError;
  AppRole? _selectedRole;

  CoreInfo? get coreInfo => _coreInfo;
  Object? get coreError => _coreError;
  AppRole? get selectedRole => _selectedRole;

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
}
