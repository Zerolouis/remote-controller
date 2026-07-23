// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

const vigemClientRevision = '8d71f6740ffff4671cdadbca255ce528e3cd3fef';
const _vigemArchiveSha256 = '2fba3b63c3fdabe2664a30645b0e8ad79e52a11be628f91313d3cdbc698c121c';
const _archiveRoot = 'Virtual-Gamepad-Emulation-Client-$vigemClientRevision/';
final _vigemDownloadUri = Uri.parse(
  'https://github.com/LizardByte/Virtual-Gamepad-Emulation-Client/'
  'archive/$vigemClientRevision.zip',
);

const _requiredFiles = <String>[
  'LICENSE',
  'include/ViGEm/Client.h',
  'include/ViGEm/Common.h',
  'include/ViGEm/Util.h',
  'include/ViGEm/km/BusShared.h',
  'src/Internal.h',
  'src/UniUtil.h',
  'src/ViGEmClient.cpp',
];

final class VigemClientSource {
  const VigemClientSource({
    required this.root,
    required this.includeDirectory,
    required this.sourceFile,
    required this.dependencies,
  });

  final Directory root;
  final Directory includeDirectory;
  final File sourceFile;
  final List<File> dependencies;
}

Future<VigemClientSource> prepareVigemClientSource({
  required Uri outputDirectory,
  String? localSourcePath,
}) async {
  if (localSourcePath != null && localSourcePath.trim().isNotEmpty) {
    return _validateSource(Directory(localSourcePath));
  }

  // Keep this path deliberately short. Native Assets output paths are already
  // deep, and MSVC does not reliably compile source paths beyond MAX_PATH.
  final sourceRoot = Directory.fromUri(outputDirectory.resolve('vigem/'));
  final cached = _tryValidateSource(sourceRoot);
  if (cached != null) {
    return cached;
  }

  final archiveBytes = await _downloadVerifiedArchive();
  final archive = ZipDecoder().decodeBytes(archiveBytes, verify: true);
  final requiredPaths = _requiredFiles.map((path) => '$_archiveRoot$path').toSet();
  for (final entry in archive) {
    if (!entry.isFile || !requiredPaths.contains(entry.name)) {
      continue;
    }
    final relativePath = entry.name.substring(_archiveRoot.length);
    final destination = File.fromUri(sourceRoot.uri.resolve(relativePath));
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(entry.content, flush: true);
  }

  return _validateSource(sourceRoot);
}

VigemClientSource? _tryValidateSource(Directory root) {
  try {
    return _validateSource(root);
  } on StateError {
    return null;
  }
}

VigemClientSource _validateSource(Directory root) {
  final files = _requiredFiles
      .map((path) => File.fromUri(root.uri.resolve(path)))
      .toList(growable: false);
  final missing = files.where((file) => !file.existsSync()).toList();
  if (missing.isNotEmpty) {
    throw StateError(
      'ViGEmClient source at ${root.path} is incomplete. Missing: '
      '${missing.map((file) => file.path).join(', ')}.',
    );
  }
  return VigemClientSource(
    root: root,
    includeDirectory: Directory.fromUri(root.uri.resolve('include/')),
    sourceFile: File.fromUri(root.uri.resolve('src/ViGEmClient.cpp')),
    dependencies: files,
  );
}

Future<Uint8List> _downloadVerifiedArchive() async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 30)
    ..findProxy = HttpClient.findProxyFromEnvironment;
  try {
    final request = await client.getUrl(_vigemDownloadUri);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Downloading $_vigemDownloadUri returned HTTP '
        '${response.statusCode}. Set the remote_controller_core hook user '
        'define vigem_source_path to the checked-out ViGEmClient revision '
        '$vigemClientRevision for offline builds.',
        uri: _vigemDownloadUri,
      );
    }

    final buffer = BytesBuilder(copy: false);
    await for (final chunk in response) {
      buffer.add(chunk);
    }
    final bytes = buffer.takeBytes();
    final actualHash = sha256.convert(bytes).toString();
    if (actualHash != _vigemArchiveSha256) {
      throw StateError(
        'ViGEmClient archive SHA-256 mismatch: expected '
        '$_vigemArchiveSha256, received $actualHash.',
      );
    }
    return bytes;
  } finally {
    client.close(force: true);
  }
}
