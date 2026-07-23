// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:remote_controller/data/models/vigem_installer_data.dart';
import 'package:remote_controller_core/remote_controller_core.dart';

const officialVigemBusInstaller = VigemInstallerSpec(
  version: '1.22.0',
  fileName: 'ViGEmBus_1.22.0_x64_x86_arm64.exe',
  downloadUrl:
      'https://github.com/nefarius/ViGEmBus/releases/download/v1.22.0/'
      'ViGEmBus_1.22.0_x64_x86_arm64.exe',
  byteLength: 6278576,
  sha256Hex: '89220a7865076b342892f98865f3499fb7c4cfd673159e89d352c360fd014c6a',
);

final class VigemInstallerSpec {
  const VigemInstallerSpec({
    required this.version,
    required this.fileName,
    required this.downloadUrl,
    required this.byteLength,
    required this.sha256Hex,
  });

  final String version;
  final String fileName;
  final String downloadUrl;
  final int byteLength;
  final String sha256Hex;

  Uri get uri => Uri.parse(downloadUrl);
}

typedef VigemInstallerDownloader = Future<Uint8List> Function(Uri uri, int maximumBytes);
typedef VigemInstallerLauncher = Future<VigemInstallerLaunchResult> Function(String installerPath);

final class VigemInstallerService {
  VigemInstallerService({
    this.spec = officialVigemBusInstaller,
    Directory? cacheDirectory,
    VigemInstallerDownloader? downloader,
    VigemInstallerLauncher? launcher,
  }) : _cacheDirectory =
           cacheDirectory ??
           Directory.fromUri(
             Directory.systemTemp.uri.resolve(
               'RemoteController/driver-installers/',
             ),
           ),
       _downloader = downloader ?? _downloadBytes,
       _launcher = launcher ?? _launchNativeInstaller;

  final VigemInstallerSpec spec;
  final Directory _cacheDirectory;
  final VigemInstallerDownloader _downloader;
  final VigemInstallerLauncher _launcher;

  Future<VigemInstallerData> downloadAndLaunch() async {
    await _cacheDirectory.create(recursive: true);
    final installer = File.fromUri(_cacheDirectory.uri.resolve(spec.fileName));
    if (!await _isVerified(installer)) {
      if (await installer.exists()) {
        await installer.delete();
      }
      await _downloadVerifiedInstaller(installer);
    }

    final launch = await _launcher(installer.path);
    if (!launch.launched) {
      if (launch.win32Error == 1223) {
        throw const VigemInstallerException('管理员权限确认已取消。');
      }
      throw VigemInstallerException(
        '无法启动 ViGEmBus 安装器（Win32 ${launch.win32Error}）。',
      );
    }

    return VigemInstallerData(
      version: spec.version,
      sourceUrl: spec.uri,
      installerPath: installer.path,
    );
  }

  Future<void> _downloadVerifiedInstaller(File installer) async {
    final bytes = await _downloader(spec.uri, spec.byteLength);
    _verifyBytes(bytes);

    final partial = File('${installer.path}.partial');
    try {
      if (await partial.exists()) {
        await partial.delete();
      }
      await partial.writeAsBytes(bytes, flush: true);
      await partial.rename(installer.path);
    } finally {
      if (await partial.exists()) {
        await partial.delete();
      }
    }
  }

  Future<bool> _isVerified(File installer) async {
    if (!await installer.exists()) {
      return false;
    }
    final bytes = await installer.readAsBytes();
    try {
      _verifyBytes(bytes);
      return true;
    } on VigemInstallerException {
      return false;
    }
  }

  void _verifyBytes(Uint8List bytes) {
    if (bytes.length != spec.byteLength) {
      throw VigemInstallerException(
        'ViGEmBus 安装器大小不匹配：预期 ${spec.byteLength}，'
        '实际 ${bytes.length}。',
      );
    }
    final actualHash = sha256.convert(bytes).toString();
    if (actualHash != spec.sha256Hex) {
      throw VigemInstallerException(
        'ViGEmBus 安装器 SHA-256 校验失败：$actualHash。',
      );
    }
  }

  static Future<Uint8List> _downloadBytes(Uri uri, int maximumBytes) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..findProxy = HttpClient.findProxyFromEnvironment;
    try {
      final request = await client.getUrl(uri);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'RemoteController ViGEmBus installer',
      );
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw VigemInstallerException(
          '下载 ViGEmBus 安装器失败：HTTP ${response.statusCode}。',
        );
      }
      if (response.contentLength > maximumBytes) {
        throw const VigemInstallerException('ViGEmBus 安装器超过允许的固定大小。');
      }

      final builder = BytesBuilder(copy: false);
      var received = 0;
      await for (final chunk in response) {
        received += chunk.length;
        if (received > maximumBytes) {
          throw const VigemInstallerException('ViGEmBus 安装器超过允许的固定大小。');
        }
        builder.add(chunk);
      }
      return builder.takeBytes();
    } finally {
      client.close(force: true);
    }
  }

  static Future<VigemInstallerLaunchResult> _launchNativeInstaller(
    String installerPath,
  ) => Isolate.run(() => VigemController.launchInstaller(installerPath));
}

final class VigemInstallerException implements Exception {
  const VigemInstallerException(this.message);

  final String message;

  @override
  String toString() => message;
}
