// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';

const sdlVersion = '3.4.12';
const sdlRuntimeAssetName = 'src/third_party/sdl3_runtime.dart';
const _sdlArchiveName = 'SDL3-devel-$sdlVersion-VC.zip';
const _sdlArchiveSha256 = '8793a153c7eba93b1eb8022fd2356383ec446b2584e43724a72ef68d682813ab';
final _sdlDownloadUri = Uri.parse(
  'https://github.com/libsdl-org/SDL/releases/download/'
  'release-$sdlVersion/$_sdlArchiveName',
);

final class SdlSdk {
  const SdlSdk({
    required this.root,
    required this.includeDirectory,
    required this.runtimeLibrary,
  });

  final Directory root;
  final Directory includeDirectory;
  final File runtimeLibrary;
}

Future<SdlSdk> prepareSdlSdk({
  required Uri outputDirectory,
  required Architecture targetArchitecture,
  String? localSdkPath,
}) async {
  final architectureDirectory = switch (targetArchitecture) {
    Architecture.x64 => 'x64',
    Architecture.arm64 => 'arm64',
    Architecture.ia32 => 'x86',
    _ => throw UnsupportedError(
      'SDL $sdlVersion does not provide a Windows VC binary for '
      '${targetArchitecture.name}.',
    ),
  };

  if (localSdkPath != null && localSdkPath.trim().isNotEmpty) {
    return _validateSdk(Directory(localSdkPath), architectureDirectory);
  }

  final extractionRoot = Directory.fromUri(
    outputDirectory.resolve('sdl-$sdlVersion/'),
  );
  final sdkRoot = Directory.fromUri(
    extractionRoot.uri.resolve('SDL3-$sdlVersion/'),
  );
  final cached = _tryValidateSdk(sdkRoot, architectureDirectory);
  if (cached != null) {
    return cached;
  }

  final archiveBytes = await _downloadVerifiedArchive();
  final archive = ZipDecoder().decodeBytes(archiveBytes, verify: true);
  final includePrefix = 'SDL3-$sdlVersion/include/';
  final runtimePath = 'SDL3-$sdlVersion/lib/$architectureDirectory/SDL3.dll';
  final licensePath = 'SDL3-$sdlVersion/LICENSE.txt';

  for (final entry in archive) {
    if (!entry.isFile ||
        (!entry.name.startsWith(includePrefix) &&
            entry.name != runtimePath &&
            entry.name != licensePath)) {
      continue;
    }
    final destination = File.fromUri(extractionRoot.uri.resolve(entry.name));
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(entry.content, flush: true);
  }

  return _validateSdk(sdkRoot, architectureDirectory);
}

SdlSdk? _tryValidateSdk(Directory root, String architectureDirectory) {
  try {
    return _validateSdk(root, architectureDirectory);
  } on StateError {
    return null;
  }
}

SdlSdk _validateSdk(Directory root, String architectureDirectory) {
  final includeDirectory = Directory.fromUri(root.uri.resolve('include/'));
  final mainHeader = File.fromUri(
    includeDirectory.uri.resolve('SDL3/SDL.h'),
  );
  final runtimeLibrary = File.fromUri(
    root.uri.resolve('lib/$architectureDirectory/SDL3.dll'),
  );
  if (!mainHeader.existsSync() || !runtimeLibrary.existsSync()) {
    throw StateError(
      'SDL SDK at ${root.path} is incomplete. Expected include/SDL3/SDL.h '
      'and lib/$architectureDirectory/SDL3.dll.',
    );
  }
  return SdlSdk(
    root: root,
    includeDirectory: includeDirectory,
    runtimeLibrary: runtimeLibrary,
  );
}

Future<Uint8List> _downloadVerifiedArchive() async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 30)
    ..findProxy = HttpClient.findProxyFromEnvironment;
  try {
    final request = await client.getUrl(_sdlDownloadUri);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Downloading $_sdlDownloadUri returned HTTP ${response.statusCode}. '
        'Set the remote_controller_core hook user define sdl_sdk_path to an '
        'extracted official SDL $sdlVersion VC SDK for offline builds.',
        uri: _sdlDownloadUri,
      );
    }

    final buffer = BytesBuilder(copy: false);
    await for (final chunk in response) {
      buffer.add(chunk);
    }
    final bytes = buffer.takeBytes();
    final actualHash = sha256.convert(bytes).toString();
    if (actualHash != _sdlArchiveSha256) {
      throw StateError(
        'SDL archive SHA-256 mismatch: expected $_sdlArchiveSha256, '
        'received $actualHash.',
      );
    }
    return bytes;
  } finally {
    client.close(force: true);
  }
}
