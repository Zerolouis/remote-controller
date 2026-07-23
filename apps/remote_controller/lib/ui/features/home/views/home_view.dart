// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'package:flutter/material.dart';
import 'package:remote_controller/domain/models/app_role.dart';
import 'package:remote_controller/ui/features/home/view_models/home_view_model.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, child) {
        final role = viewModel.selectedRole;
        return Scaffold(
          body: SafeArea(
            child: role == null
                ? _RoleSelection(viewModel: viewModel)
                : _RoleDashboard(role: role, viewModel: viewModel),
          ),
        );
      },
    );
  }
}

class _RoleSelection extends StatelessWidget {
  const _RoleSelection({required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'REMOTE CONTROLLER',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  letterSpacing: 2.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text('让掌机手柄只出现在你的电脑上', style: theme.textTheme.headlineLarge),
              const SizedBox(height: 12),
              Text(
                '选择这台设备的角色。首个版本聚焦单客户端、单手柄和低延迟局域网传输。',
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 28),
              _CoreStatus(viewModel: viewModel),
              const SizedBox(height: 28),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cards = [
                    _RoleCard(
                      key: const Key('client-role'),
                      role: AppRole.client,
                      icon: Icons.sports_esports_rounded,
                      onTap: () => viewModel.selectRole(AppRole.client),
                    ),
                    _RoleCard(
                      key: const Key('server-role'),
                      role: AppRole.server,
                      icon: Icons.desktop_windows_rounded,
                      onTap: () => viewModel.selectRole(AppRole.server),
                    ),
                  ];
                  if (constraints.maxWidth >= 760) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: cards.first),
                        const SizedBox(width: 20),
                        Expanded(child: cards.last),
                      ],
                    );
                  }
                  return Column(
                    children: [cards.first, const SizedBox(height: 16), cards.last],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoreStatus extends StatelessWidget {
  const _CoreStatus({required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final info = viewModel.coreInfo;
    final healthy = info != null && info.abiVersion == 1;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: healthy ? const Color(0xff0b2925) : const Color(0xff35191d),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: healthy ? const Color(0xff2dd4bf) : const Color(0xfffb7185),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              healthy ? Icons.check_circle_rounded : Icons.error_rounded,
              color: healthy ? const Color(0xff5eead4) : const Color(0xffff8fa3),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                healthy ? 'Windows 原生核心已加载 · ABI ${info.abiVersion}' : 'Windows 原生核心未就绪',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({super.key, required this.role, required this.icon, required this.onTap});

  final AppRole role;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 42, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text(role.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 10),
              Text(
                role.description,
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text('选择', style: TextStyle(color: theme.colorScheme.primary)),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, color: theme.colorScheme.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleDashboard extends StatelessWidget {
  const _RoleDashboard({required this.role, required this.viewModel});

  final AppRole role;
  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final isClient = role == AppRole.client;
    final steps = isClient
        ? const [
            ('1', '选择手柄', 'ROG Ally X 内置手柄识别将在下一阶段接入 SDL 3。'),
            ('2', '开启独占', '仅在传输期间通过 HidHide 隔离本机输入。'),
            ('3', '连接电脑', '自动发现并完成六位数加密配对。'),
          ]
        : const [
            ('1', '检查驱动', '检测 ViGEmBus；缺失时只提供官方安装入口。'),
            ('2', '等待配对', '监听局域网发现和加密控制通道。'),
            ('3', '创建手柄', '收到输入后创建单个虚拟 Xbox 360 手柄。'),
          ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                key: const Key('back-to-roles'),
                onPressed: viewModel.clearRole,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('切换角色'),
              ),
              const SizedBox(height: 16),
              Text(role.title, style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              const Text('原生安全会话与本机 loopback 已就绪，硬件与网络后端尚未启用。'),
              const SizedBox(height: 20),
              _LoopbackDiagnosticCard(viewModel: viewModel),
              const SizedBox(height: 28),
              for (final step in steps) ...[
                _SetupStep(number: step.$1, title: step.$2, description: step.$3),
                const SizedBox(height: 14),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: null,
                icon: Icon(isClient ? Icons.link_rounded : Icons.power_settings_new_rounded),
                label: Text(isClient ? '开始连接（待实现）' : '启动服务（待实现）'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoopbackDiagnosticCard extends StatelessWidget {
  const _LoopbackDiagnosticCard({required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final result = viewModel.diagnostic;
    final error = viewModel.diagnosticError;
    final running = viewModel.isRunningDiagnostic;
    final Color accent;
    final String message;
    if (running) {
      accent = Theme.of(context).colorScheme.primary;
      message = '正在验证完整状态传递和输入超时自动归零…';
    } else if (result != null) {
      accent = const Color(0xff5eead4);
      message =
          '自检通过 · ${result.acceptedStateCount} 个完整状态 · '
          '${result.neutralizationCount} 次安全归零 · ${result.elapsedMilliseconds} ms';
    } else if (error != null) {
      accent = const Color(0xffff8fa3);
      message = '自检失败：$error';
    } else {
      accent = Colors.white54;
      message = '尚未运行。此测试完全在本机原生核心中完成，不会创建系统虚拟手柄。';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.health_and_safety_rounded, color: accent),
                const SizedBox(width: 10),
                Text('原生链路安全自检', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 10),
            Text(message, key: const Key('loopback-diagnostic-status')),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              key: const Key('run-loopback-diagnostic'),
              onPressed: running ? null : viewModel.runLoopbackDiagnostic,
              icon: running
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(running ? '正在自检' : '运行本机链路自检'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({required this.number, required this.title, required this.description});

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(child: Text(number)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
