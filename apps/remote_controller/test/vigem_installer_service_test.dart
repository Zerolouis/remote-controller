// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_controller/data/services/vigem_installer_service.dart';
import 'package:remote_controller_core/remote_controller_core.dart';

void main() {
  test('downloads, verifies, caches, and launches the pinned installer', () async {
    final cacheDirectory = await Directory.systemTemp.createTemp(
      'remote-controller-vigem-test-',
    );
    addTearDown(() => cacheDirectory.delete(recursive: true));
    final bytes = Uint8List.fromList('verified installer'.codeUnits);
    var downloadCount = 0;
    var launchCount = 0;
    String? launchedPath;
    final service = VigemInstallerService(
      spec: _specFor(bytes),
      cacheDirectory: cacheDirectory,
      downloader: (uri, maximumBytes) async {
        downloadCount += 1;
        expect(maximumBytes, bytes.length);
        return bytes;
      },
      launcher: (path) async {
        launchCount += 1;
        launchedPath = path;
        return const VigemInstallerLaunchResult(
          launched: true,
          win32Error: 0,
        );
      },
    );

    final first = await service.downloadAndLaunch();
    final second = await service.downloadAndLaunch();

    expect(first.version, 'test');
    expect(second.installerPath, first.installerPath);
    expect(downloadCount, 1);
    expect(launchCount, 2);
    expect(launchedPath, first.installerPath);
    expect(await File(first.installerPath).readAsBytes(), bytes);
  });

  test('rejects bytes that do not match the pinned SHA-256', () async {
    final cacheDirectory = await Directory.systemTemp.createTemp(
      'remote-controller-vigem-test-',
    );
    addTearDown(() => cacheDirectory.delete(recursive: true));
    final expected = Uint8List.fromList('expected'.codeUnits);
    final received = Uint8List.fromList('tampered'.codeUnits);
    var launched = false;
    final service = VigemInstallerService(
      spec: _specFor(expected),
      cacheDirectory: cacheDirectory,
      downloader: (uri, maximumBytes) async => received,
      launcher: (path) async {
        launched = true;
        return const VigemInstallerLaunchResult(
          launched: true,
          win32Error: 0,
        );
      },
    );

    await expectLater(
      service.downloadAndLaunch(),
      throwsA(
        isA<VigemInstallerException>().having(
          (error) => error.message,
          'message',
          contains('SHA-256'),
        ),
      ),
    );
    expect(launched, isFalse);
  });

  test('reports a cancelled Windows UAC prompt', () async {
    final cacheDirectory = await Directory.systemTemp.createTemp(
      'remote-controller-vigem-test-',
    );
    addTearDown(() => cacheDirectory.delete(recursive: true));
    final bytes = Uint8List.fromList('verified installer'.codeUnits);
    final service = VigemInstallerService(
      spec: _specFor(bytes),
      cacheDirectory: cacheDirectory,
      downloader: (uri, maximumBytes) async => bytes,
      launcher: (path) async => const VigemInstallerLaunchResult(
        launched: false,
        win32Error: 1223,
      ),
    );

    await expectLater(
      service.downloadAndLaunch(),
      throwsA(
        isA<VigemInstallerException>().having(
          (error) => error.message,
          'message',
          contains('管理员权限确认已取消'),
        ),
      ),
    );
  });
}

VigemInstallerSpec _specFor(Uint8List bytes) => VigemInstallerSpec(
  version: 'test',
  fileName: 'installer.exe',
  downloadUrl: 'https://example.invalid/installer.exe',
  byteLength: bytes.length,
  sha256Hex: sha256.convert(bytes).toString(),
);
