// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:remote_controller/data/repositories/core_repository.dart';
import 'package:remote_controller/domain/models/app_role.dart';
import 'package:remote_controller/domain/models/core_info.dart';
import 'package:remote_controller/domain/models/input_capture_snapshot.dart';
import 'package:remote_controller/domain/models/input_device.dart';
import 'package:remote_controller/domain/models/lan_session.dart';
import 'package:remote_controller/domain/models/loopback_diagnostic.dart';
import 'package:remote_controller/domain/models/virtual_controller.dart';

final class HomeViewModel extends ChangeNotifier {
  HomeViewModel(this._coreRepository);

  final CoreRepository _coreRepository;

  CoreInfo? _coreInfo;
  Object? _coreError;
  AppRole? _selectedRole;
  bool _isRunningDiagnostic = false;
  LoopbackDiagnostic? _diagnostic;
  Object? _diagnosticError;
  InputRuntime? _inputRuntime;
  List<InputDevice> _inputDevices = const [];
  bool _isLoadingInputDevices = false;
  Object? _inputError;
  int? _capturedDeviceId;
  InputCaptureSnapshot? _inputCaptureSnapshot;
  Timer? _capturePollTimer;
  VirtualControllerRuntime? _virtualControllerRuntime;
  bool _isInstallingVigemBus = false;
  String? _vigemInstallStatus;
  Object? _vigemInstallError;
  int? _bridgedDeviceId;
  LocalBridgeSnapshot? _localBridgeSnapshot;
  Object? _bridgeError;
  Timer? _bridgePollTimer;
  String _serverAddress = '127.0.0.1';
  int? _lanClientDeviceId;
  bool _lanServerActive = false;
  LanSessionStatus? _lanSessionStatus;
  Object? _lanSessionError;
  Timer? _lanPollTimer;

  CoreInfo? get coreInfo => _coreInfo;
  Object? get coreError => _coreError;
  AppRole? get selectedRole => _selectedRole;
  bool get isRunningDiagnostic => _isRunningDiagnostic;
  LoopbackDiagnostic? get diagnostic => _diagnostic;
  Object? get diagnosticError => _diagnosticError;
  InputRuntime? get inputRuntime => _inputRuntime;
  List<InputDevice> get inputDevices => _inputDevices;
  bool get isLoadingInputDevices => _isLoadingInputDevices;
  Object? get inputError => _inputError;
  int? get capturedDeviceId => _capturedDeviceId;
  InputCaptureSnapshot? get inputCaptureSnapshot => _inputCaptureSnapshot;
  VirtualControllerRuntime? get virtualControllerRuntime => _virtualControllerRuntime;
  bool get isInstallingVigemBus => _isInstallingVigemBus;
  String? get vigemInstallStatus => _vigemInstallStatus;
  Object? get vigemInstallError => _vigemInstallError;
  int? get bridgedDeviceId => _bridgedDeviceId;
  LocalBridgeSnapshot? get localBridgeSnapshot => _localBridgeSnapshot;
  Object? get bridgeError => _bridgeError;
  String get serverAddress => _serverAddress;
  int? get lanClientDeviceId => _lanClientDeviceId;
  bool get lanServerActive => _lanServerActive;
  LanSessionStatus? get lanSessionStatus => _lanSessionStatus;
  Object? get lanSessionError => _lanSessionError;

  void initialize() {
    try {
      _coreInfo = _coreRepository.getCoreInfo();
      _inputRuntime = _coreRepository.getInputRuntime();
      _virtualControllerRuntime = _coreRepository.getVirtualControllerRuntime();
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
    if (role == AppRole.client) {
      unawaited(refreshInputDevices());
    }
  }

  void clearRole() {
    if (_selectedRole == null) {
      return;
    }
    stopInputCapture();
    stopLocalBridge();
    stopLanClient();
    stopLanServer();
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

  Future<void> refreshInputDevices() async {
    if (_isLoadingInputDevices ||
        _capturedDeviceId != null ||
        _bridgedDeviceId != null ||
        _lanClientDeviceId != null) {
      return;
    }
    _isLoadingInputDevices = true;
    _inputError = null;
    notifyListeners();
    try {
      _inputDevices = await _coreRepository.enumerateInputDevices();
    } on Object catch (error) {
      _inputDevices = const [];
      _inputError = error;
    } finally {
      _isLoadingInputDevices = false;
      notifyListeners();
    }
  }

  Future<void> installVigemBus() async {
    if (_isInstallingVigemBus || _virtualControllerRuntime?.available == true) {
      return;
    }
    _isInstallingVigemBus = true;
    _vigemInstallStatus = '正在下载并校验官方 ViGEmBus 安装器…';
    _vigemInstallError = null;
    notifyListeners();

    try {
      final result = await _coreRepository.installVigemBus();
      _vigemInstallStatus =
          'ViGEmBus ${result.version} 安装器已启动。完成安装后请重新检测；'
          'Windows 可能要求重启。';
    } on Object catch (error) {
      _vigemInstallStatus = null;
      _vigemInstallError = error;
    } finally {
      _isInstallingVigemBus = false;
      notifyListeners();
    }
  }

  void refreshVirtualControllerRuntime() {
    try {
      final hadInstallerLaunch = _vigemInstallStatus != null;
      _virtualControllerRuntime = _coreRepository.getVirtualControllerRuntime();
      _vigemInstallError = null;
      if (_virtualControllerRuntime?.available == true) {
        _vigemInstallStatus = 'ViGEmBus 已可用。';
      } else if (hadInstallerLaunch) {
        _vigemInstallStatus = '仍未检测到 ViGEmBus；请完成安装或重启 Windows 后再检测。';
      }
    } on Object catch (error) {
      _vigemInstallError = error;
    }
    notifyListeners();
  }

  void startInputCapture(InputDevice device) {
    stopLocalBridge();
    stopLanClient();
    if (_capturedDeviceId != null) {
      stopInputCapture();
    }
    try {
      _coreRepository.startInputCapture(device.instanceId);
      _capturedDeviceId = device.instanceId;
      _inputCaptureSnapshot = _coreRepository.getInputCaptureSnapshot();
      _inputError = null;
      _capturePollTimer = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => _pollInputCapture(),
      );
    } on Object catch (error) {
      _capturedDeviceId = null;
      _inputCaptureSnapshot = null;
      _inputError = error;
    }
    notifyListeners();
  }

  void stopInputCapture() {
    _capturePollTimer?.cancel();
    _capturePollTimer = null;
    _coreRepository.stopInputCapture();
    _capturedDeviceId = null;
    _inputCaptureSnapshot = null;
    notifyListeners();
  }

  void _pollInputCapture() {
    try {
      final snapshot = _coreRepository.getInputCaptureSnapshot();
      _inputCaptureSnapshot = snapshot;
      if (snapshot.state == 'disconnected' || snapshot.state == 'faulted') {
        _capturePollTimer?.cancel();
        _capturePollTimer = null;
      }
      _inputError = null;
    } on Object catch (error) {
      _inputError = error;
      _capturePollTimer?.cancel();
      _capturePollTimer = null;
    }
    notifyListeners();
  }

  void startLocalBridge(InputDevice device) {
    stopInputCapture();
    stopLanClient();
    if (_bridgedDeviceId != null) {
      stopLocalBridge();
    }
    try {
      _coreRepository.startLocalBridge(device.instanceId);
      _bridgedDeviceId = device.instanceId;
      _localBridgeSnapshot = _coreRepository.getLocalBridgeSnapshot();
      _bridgeError = null;
      _bridgePollTimer = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => _pollLocalBridge(),
      );
    } on Object catch (error) {
      _bridgedDeviceId = null;
      _localBridgeSnapshot = null;
      _bridgeError = error;
    }
    notifyListeners();
  }

  void stopLocalBridge() {
    _bridgePollTimer?.cancel();
    _bridgePollTimer = null;
    _coreRepository.stopLocalBridge();
    _bridgedDeviceId = null;
    _localBridgeSnapshot = null;
    notifyListeners();
  }

  void _pollLocalBridge() {
    try {
      final snapshot = _coreRepository.getLocalBridgeSnapshot();
      _localBridgeSnapshot = snapshot;
      if (snapshot.state == 'disconnected' || snapshot.state == 'faulted') {
        _bridgePollTimer?.cancel();
        _bridgePollTimer = null;
      }
      _bridgeError = null;
    } on Object catch (error) {
      _bridgeError = error;
      _bridgePollTimer?.cancel();
      _bridgePollTimer = null;
    }
    notifyListeners();
  }

  void setServerAddress(String value) {
    _serverAddress = value;
  }

  void startLanClient(InputDevice device) {
    final address = _serverAddress.trim();
    if (address.isEmpty) {
      _lanSessionError = ArgumentError('请输入电脑的 IPv4 地址或主机名。');
      notifyListeners();
      return;
    }
    stopInputCapture();
    stopLocalBridge();
    stopLanClient();
    try {
      _coreRepository.startLanClient(device.instanceId, address);
      _lanClientDeviceId = device.instanceId;
      _lanServerActive = false;
      _lanSessionStatus = _coreRepository.getLanClientStatus();
      _lanSessionError = null;
      _startLanPolling();
    } on Object catch (error) {
      _lanClientDeviceId = null;
      _lanSessionStatus = null;
      _lanSessionError = error;
    }
    notifyListeners();
  }

  void stopLanClient() {
    if (_lanClientDeviceId == null) {
      return;
    }
    _lanPollTimer?.cancel();
    _lanPollTimer = null;
    _coreRepository.stopLanClient();
    _lanClientDeviceId = null;
    _lanSessionStatus = null;
    notifyListeners();
  }

  void startLanServer() {
    if (_lanServerActive || _virtualControllerRuntime?.available != true) {
      return;
    }
    stopLanServer();
    try {
      _coreRepository.startLanServer();
      _lanServerActive = true;
      _lanClientDeviceId = null;
      _lanSessionStatus = _coreRepository.getLanServerStatus();
      _lanSessionError = null;
      _startLanPolling();
    } on Object catch (error) {
      _lanServerActive = false;
      _lanSessionStatus = null;
      _lanSessionError = error;
    }
    notifyListeners();
  }

  void stopLanServer() {
    if (!_lanServerActive) {
      return;
    }
    _lanPollTimer?.cancel();
    _lanPollTimer = null;
    _coreRepository.stopLanServer();
    _lanServerActive = false;
    _lanSessionStatus = null;
    notifyListeners();
  }

  void _startLanPolling() {
    _lanPollTimer?.cancel();
    _lanPollTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _pollLanSession(),
    );
  }

  void _pollLanSession() {
    try {
      final status = _lanClientDeviceId != null
          ? _coreRepository.getLanClientStatus()
          : _coreRepository.getLanServerStatus();
      _lanSessionStatus = status;
      _lanSessionError = null;
      if (status.state == 'disconnected' || status.state == 'faulted') {
        _lanPollTimer?.cancel();
        _lanPollTimer = null;
      }
    } on Object catch (error) {
      _lanSessionError = error;
      _lanPollTimer?.cancel();
      _lanPollTimer = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _capturePollTimer?.cancel();
    _bridgePollTimer?.cancel();
    _lanPollTimer?.cancel();
    _coreRepository.dispose();
    super.dispose();
  }
}
