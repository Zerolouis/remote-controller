// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_controller/app.dart';
import 'package:remote_controller/data/repositories/core_repository.dart';
import 'package:remote_controller/domain/models/core_info.dart';

void main() {
  testWidgets('shows healthy native core and both roles', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const RemoteControllerApp(coreRepository: _FakeCoreRepository()));
    await tester.pump();

    expect(find.text('Windows 原生核心已加载 · ABI 1'), findsOneWidget);
    expect(find.text('掌机客户端'), findsOneWidget);
    expect(find.text('电脑服务端'), findsOneWidget);
  });

  testWidgets('selects server role and returns to role selection', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const RemoteControllerApp(coreRepository: _FakeCoreRepository()));
    await tester.tap(find.byKey(const Key('server-role')));
    await tester.pump();

    expect(find.text('检查驱动'), findsOneWidget);
    expect(find.text('启动服务（待实现）'), findsOneWidget);

    await tester.tap(find.byKey(const Key('back-to-roles')));
    await tester.pump();

    expect(find.byKey(const Key('client-role')), findsOneWidget);
  });
}

final class _FakeCoreRepository implements CoreRepository {
  const _FakeCoreRepository();

  @override
  CoreInfo getCoreInfo() => const CoreInfo(
    abiVersion: 1,
    buildInfo: 'remote-controller-core/test',
  );
}
