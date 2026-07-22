// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'package:flutter/material.dart';
import 'package:remote_controller/data/repositories/core_repository.dart';
import 'package:remote_controller/ui/features/home/view_models/home_view_model.dart';
import 'package:remote_controller/ui/features/home/views/home_view.dart';

class RemoteControllerApp extends StatefulWidget {
  const RemoteControllerApp({super.key, required this.coreRepository});

  final CoreRepository coreRepository;

  @override
  State<RemoteControllerApp> createState() => _RemoteControllerAppState();
}

class _RemoteControllerAppState extends State<RemoteControllerApp> {
  late final HomeViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = HomeViewModel(widget.coreRepository)..initialize();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remote Controller',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff67e8f9),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xff080d15),
        cardTheme: const CardThemeData(
          color: Color(0xff111827),
          margin: EdgeInsets.zero,
        ),
        useMaterial3: true,
      ),
      home: HomeView(viewModel: _viewModel),
    );
  }
}
