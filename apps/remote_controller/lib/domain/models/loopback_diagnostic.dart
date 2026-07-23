// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

final class LoopbackDiagnostic {
  const LoopbackDiagnostic({
    required this.acceptedStateCount,
    required this.neutralizationCount,
    required this.elapsedMilliseconds,
  });

  final int acceptedStateCount;
  final int neutralizationCount;
  final int elapsedMilliseconds;
}
