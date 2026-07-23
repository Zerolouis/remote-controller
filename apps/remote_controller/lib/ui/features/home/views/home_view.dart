// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'package:flutter/material.dart';
import 'package:remote_controller/domain/models/app_role.dart';
import 'package:remote_controller/domain/models/input_capture_snapshot.dart';
import 'package:remote_controller/domain/models/input_device.dart';
import 'package:remote_controller/domain/models/lan_session.dart';
import 'package:remote_controller/domain/models/virtual_controller.dart';
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
            ('1', '选择手柄', 'SDL 3 已接入；先确认设备身份和原始数值范围。'),
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
              Text(
                isClient
                    ? 'SDL 3 读取、本机桥接和局域网诊断发送已就绪；HidHide 尚未启用。'
                    : 'ViGEm 虚拟 Xbox 360 后端和局域网诊断接收已就绪。',
              ),
              if (isClient) ...[
                const SizedBox(height: 20),
                _InputDeviceCard(viewModel: viewModel),
              ] else ...[
                const SizedBox(height: 20),
                _VirtualControllerCard(viewModel: viewModel),
              ],
              const SizedBox(height: 20),
              _LanDiagnosticCard(isClient: isClient, viewModel: viewModel),
              const SizedBox(height: 20),
              _LoopbackDiagnosticCard(viewModel: viewModel),
              const SizedBox(height: 28),
              for (final step in steps) ...[
                _SetupStep(number: step.$1, title: step.$2, description: step.$3),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InputDeviceCard extends StatelessWidget {
  const _InputDeviceCard({required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final runtime = viewModel.inputRuntime;
    final devices = viewModel.inputDevices;
    final error = viewModel.inputError;
    final loading = viewModel.isLoadingInputDevices;
    final capture = viewModel.inputCaptureSnapshot;
    final bridge = viewModel.localBridgeSnapshot;
    final vigem = viewModel.virtualControllerRuntime;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sports_esports_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'SDL 实体手柄',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('refresh-input-devices'),
                  onPressed:
                      loading ||
                          viewModel.capturedDeviceId != null ||
                          viewModel.bridgedDeviceId != null
                      ? null
                      : viewModel.refreshInputDevices,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重新扫描'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              vigem == null
                  ? 'ViGEmBus 状态未知'
                  : vigem.available
                  ? 'ViGEmBus 可用 · 可创建单个虚拟 Xbox 360 手柄并接收震动'
                  : 'ViGEmBus 不可用：${vigem.error}',
              key: const Key('vigem-runtime-status'),
              style: TextStyle(
                color: vigem?.available == true ? const Color(0xff5eead4) : const Color(0xffff8fa3),
              ),
            ),
            _VigemInstallerControls(
              viewModel: viewModel,
              keyPrefix: 'client',
            ),
            const SizedBox(height: 8),
            Text(
              runtime == null
                  ? 'SDL 状态未知'
                  : runtime.available
                  ? 'SDL ${runtime.version} · 原生 250 Hz 采样，界面仅显示 10 Hz 快照'
                  : 'SDL 不可用：${runtime.error}',
              key: const Key('sdl-runtime-status'),
              style: TextStyle(
                color: runtime?.available == true
                    ? const Color(0xff5eead4)
                    : const Color(0xffff8fa3),
              ),
            ),
            if (loading) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ] else if (error != null) ...[
              const SizedBox(height: 14),
              Text('手柄读取错误：$error', style: const TextStyle(color: Color(0xffff8fa3))),
            ] else if (devices.isEmpty) ...[
              const SizedBox(height: 14),
              const Text('未检测到 SDL 标准手柄。请确认掌机处于手柄模式后重新扫描。'),
            ] else ...[
              const SizedBox(height: 14),
              for (final device in devices) ...[
                _InputDeviceTile(device: device, viewModel: viewModel),
                if (device != devices.last) const SizedBox(height: 10),
              ],
            ],
            if (capture != null) ...[
              const SizedBox(height: 14),
              _RawCapturePanel(snapshot: capture),
            ],
            if (viewModel.bridgeError != null) ...[
              const SizedBox(height: 14),
              Text(
                '本机桥接错误：${viewModel.bridgeError}',
                style: const TextStyle(color: Color(0xffff8fa3)),
              ),
            ],
            if (bridge != null) ...[
              const SizedBox(height: 14),
              _LocalBridgePanel(snapshot: bridge),
            ],
          ],
        ),
      ),
    );
  }
}

class _InputDeviceTile extends StatelessWidget {
  const _InputDeviceTile({required this.device, required this.viewModel});

  final InputDevice device;
  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final captureActive = viewModel.capturedDeviceId == device.instanceId;
    final bridgeActive = viewModel.bridgedDeviceId == device.instanceId;
    final lanActive = viewModel.lanClientDeviceId == device.instanceId;
    final active = captureActive || bridgeActive || lanActive;
    final anotherActive =
        (viewModel.capturedDeviceId != null && !captureActive) ||
        (viewModel.bridgedDeviceId != null && !bridgeActive) ||
        (viewModel.lanClientDeviceId != null && !lanActive);
    return DecoratedBox(
      key: Key('input-device-${device.instanceId}'),
      decoration: BoxDecoration(
        color: const Color(0xff0b1220),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? Theme.of(context).colorScheme.primary : Colors.white12,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device.name, style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        'VID ${_hex(device.vendorId, 4)} · PID ${_hex(device.productId, 4)} · '
                        '实例 ${device.instanceId}',
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                if (device.isRogAllyX)
                  const Chip(
                    avatar: Icon(Icons.verified_rounded, size: 16),
                    label: Text('ROG Ally X'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CapabilityChip(
                  label: device.supportsAnalogTriggers ? '模拟扳机' : '扳机能力未知',
                ),
                _CapabilityChip(label: device.supportsRumble ? '支持震动' : '震动能力未知'),
                _CapabilityChip(
                  label: '按键 0x${_hex(device.supportedButtons, 8)}',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('GUID ${device.guid}', style: const TextStyle(color: Colors.white60)),
            if (device.path.isNotEmpty) ...[
              const SizedBox(height: 4),
              SelectableText(
                device.path,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  key: Key(
                    captureActive ? 'stop-input-capture' : 'capture-device-${device.instanceId}',
                  ),
                  onPressed: anotherActive || bridgeActive || lanActive
                      ? null
                      : captureActive
                      ? viewModel.stopInputCapture
                      : () => viewModel.startInputCapture(device),
                  icon: Icon(
                    captureActive ? Icons.stop_rounded : Icons.monitor_heart_rounded,
                  ),
                  label: Text(captureActive ? '停止原始值记录' : '记录原始值'),
                ),
                FilledButton.tonalIcon(
                  key: Key(
                    bridgeActive ? 'stop-local-bridge' : 'bridge-device-${device.instanceId}',
                  ),
                  onPressed:
                      anotherActive ||
                          captureActive ||
                          lanActive ||
                          viewModel.virtualControllerRuntime?.available != true
                      ? null
                      : bridgeActive
                      ? viewModel.stopLocalBridge
                      : () => viewModel.startLocalBridge(device),
                  icon: Icon(
                    bridgeActive ? Icons.stop_rounded : Icons.cable_rounded,
                  ),
                  label: Text(bridgeActive ? '停止本机桥接' : '桥接到虚拟 X360'),
                ),
                FilledButton.icon(
                  key: Key(
                    lanActive ? 'stop-lan-client' : 'lan-client-device-${device.instanceId}',
                  ),
                  onPressed: anotherActive || captureActive || bridgeActive
                      ? null
                      : lanActive
                      ? viewModel.stopLanClient
                      : () => viewModel.startLanClient(device),
                  icon: Icon(
                    lanActive ? Icons.stop_rounded : Icons.wifi_tethering_rounded,
                  ),
                  label: Text(lanActive ? '停止局域网发送' : '发送到电脑'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LanDiagnosticCard extends StatelessWidget {
  const _LanDiagnosticCard({
    required this.isClient,
    required this.viewModel,
  });

  final bool isClient;
  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final status = viewModel.lanSessionStatus;
    final active = isClient ? viewModel.lanClientDeviceId != null : viewModel.lanServerActive;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lan_rounded,
                  color: status?.connected == true
                      ? const Color(0xff5eead4)
                      : const Color(0xfffbbf24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '局域网 Client–Server 诊断链路',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Chip(label: Text('未加密诊断版')),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'TCP 26760 负责握手、心跳、停止和震动；UDP 26760 发送 64 字节完整状态。'
              '当前没有配对或 AEAD，只能在可信局域网测试。',
              style: TextStyle(color: Color(0xfffde68a)),
            ),
            const SizedBox(height: 14),
            if (isClient) ...[
              TextFormField(
                key: const Key('lan-server-address'),
                initialValue: viewModel.serverAddress,
                enabled: !active,
                onChanged: viewModel.setServerAddress,
                decoration: const InputDecoration(
                  labelText: '电脑 IPv4 地址或主机名',
                  hintText: '例如 192.168.1.20',
                  prefixIcon: Icon(Icons.dns_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                active ? '已使用所选手柄启动发送；请在设备卡片中停止。' : '填写电脑地址后，在上方目标手柄卡片点击“发送到电脑”。',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              const Text(
                'HidHide 尚未启用，本机程序仍可能同时收到实体手柄输入。',
                style: TextStyle(color: Color(0xffffb4c0)),
              ),
            ] else ...[
              FilledButton.icon(
                key: Key(active ? 'stop-lan-server' : 'start-lan-server'),
                onPressed: viewModel.virtualControllerRuntime?.available != true
                    ? null
                    : active
                    ? viewModel.stopLanServer
                    : viewModel.startLanServer,
                icon: Icon(
                  active ? Icons.stop_rounded : Icons.power_settings_new_rounded,
                ),
                label: Text(active ? '停止局域网服务' : '监听 TCP/UDP 26760'),
              ),
              const SizedBox(height: 10),
              const Text(
                '首次监听时 Windows 防火墙可能要求允许专用网络访问。服务端一次只接受一个客户端。',
                style: TextStyle(color: Colors.white70),
              ),
            ],
            if (viewModel.lanSessionError != null) ...[
              const SizedBox(height: 12),
              Text(
                '局域网会话错误：${viewModel.lanSessionError}',
                key: const Key('lan-session-error'),
                style: const TextStyle(color: Color(0xffff8fa3)),
              ),
            ],
            if (status != null) ...[
              const SizedBox(height: 14),
              _LanStatusPanel(status: status, isClient: isClient),
            ],
          ],
        ),
      ),
    );
  }
}

class _LanStatusPanel extends StatelessWidget {
  const _LanStatusPanel({required this.status, required this.isClient});

  final LanSessionStatus status;
  final bool isClient;

  @override
  Widget build(BuildContext context) {
    final connectionLabel = status.connected
        ? '已连接 ${status.peerAddress}'
        : status.state == 'running'
        ? (isClient ? '正在连接电脑…' : '正在等待客户端…')
        : status.state;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xff071a19),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status.connected ? const Color(0xff2dd4bf) : const Color(0xfffbbf24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              connectionLabel,
              key: const Key('lan-session-status'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '发送 ${status.sentPacketCount} · 接收 ${status.receivedPacketCount} · '
              '丢弃 ${status.droppedPacketCount} · 序列 ${status.latestSequence} · '
              '安全归零 ${status.neutralizationCount}',
              style: const TextStyle(fontFamily: 'Consolas'),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _RawMetric(
                  label: 'Buttons',
                  value: '0x${_hex(status.buttonFlags, 8)}',
                ),
                _RawMetric(label: 'LT', value: '${status.leftTrigger}'),
                _RawMetric(label: 'RT', value: '${status.rightTrigger}'),
                _RawMetric(label: 'LX', value: '${status.leftStickX}'),
                _RawMetric(label: 'LY', value: '${status.leftStickY}'),
                _RawMetric(label: 'RX', value: '${status.rightStickX}'),
                _RawMetric(label: 'RY', value: '${status.rightStickY}'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '震动 ${status.rumbleCount} 次 · '
              '低频 ${status.lowFrequencyMotor} · 高频 ${status.highFrequencyMotor}',
              style: const TextStyle(fontFamily: 'Consolas'),
            ),
            if (status.error.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${status.error} (Winsock ${status.lastError})',
                style: const TextStyle(color: Color(0xffff8fa3)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VirtualControllerCard extends StatelessWidget {
  const _VirtualControllerCard({required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final runtime = viewModel.virtualControllerRuntime;
    final available = runtime?.available == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              available ? Icons.gamepad_rounded : Icons.error_outline_rounded,
              color: available ? const Color(0xff5eead4) : const Color(0xffff8fa3),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ViGEm 虚拟 Xbox 360 后端',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    runtime == null
                        ? '驱动状态未知'
                        : available
                        ? 'ViGEmBus 已连接，可创建单个 X360 target 并接收双马达震动。'
                        : 'ViGEmBus 不可用：${runtime.error} '
                              '(0x${_hex(runtime.resultCode, 8)})',
                    key: const Key('server-vigem-status'),
                  ),
                  _VigemInstallerControls(
                    viewModel: viewModel,
                    keyPrefix: 'server',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VigemInstallerControls extends StatelessWidget {
  const _VigemInstallerControls({
    required this.viewModel,
    required this.keyPrefix,
  });

  final HomeViewModel viewModel;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final unavailable = viewModel.virtualControllerRuntime?.available == false;
    final status = viewModel.vigemInstallStatus;
    final error = viewModel.vigemInstallError;
    if (!unavailable && status == null && error == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (unavailable) ...[
            const Text(
              '可下载官方最终版 ViGEmBus 1.22.0。应用会校验固定 SHA-256，'
              '随后显示标准 Windows UAC；不会静默安装或捆绑驱动。',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  key: Key('install-vigem-$keyPrefix'),
                  onPressed: viewModel.isInstallingVigemBus ? null : viewModel.installVigemBus,
                  icon: viewModel.isInstallingVigemBus
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded),
                  label: Text(
                    viewModel.isInstallingVigemBus ? '正在准备安装器' : '安装 ViGEmBus 1.22.0',
                  ),
                ),
                OutlinedButton.icon(
                  key: Key('refresh-vigem-$keyPrefix'),
                  onPressed: viewModel.isInstallingVigemBus
                      ? null
                      : viewModel.refreshVirtualControllerRuntime,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重新检测'),
                ),
              ],
            ),
          ],
          if (status != null) ...[
            const SizedBox(height: 10),
            Text(
              status,
              key: Key('vigem-install-status-$keyPrefix'),
              style: const TextStyle(color: Color(0xfffde68a)),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              'ViGEmBus 安装失败：$error',
              key: Key('vigem-install-error-$keyPrefix'),
              style: const TextStyle(color: Color(0xffff8fa3)),
            ),
          ],
        ],
      ),
    );
  }
}

class _LocalBridgePanel extends StatelessWidget {
  const _LocalBridgePanel({required this.snapshot});

  final LocalBridgeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xff17140a),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xfffbbf24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '本机 SDL → ViGEm · ${snapshot.sampleCount} 个样本 · '
              '${snapshot.state}',
              key: const Key('local-bridge-status'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'HidHide 尚未启用：实体和虚拟手柄会同时可见，游戏中可能产生双输入。',
              style: TextStyle(color: Color(0xfffde68a)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _RawMetric(
                  label: 'Buttons',
                  value: '0x${_hex(snapshot.buttonFlags, 8)}',
                ),
                _RawMetric(label: 'LT', value: '${snapshot.leftTrigger}'),
                _RawMetric(label: 'RT', value: '${snapshot.rightTrigger}'),
                _RawMetric(label: 'LX', value: '${snapshot.leftStickX}'),
                _RawMetric(label: 'LY', value: '${snapshot.leftStickY}'),
                _RawMetric(label: 'RX', value: '${snapshot.rightStickX}'),
                _RawMetric(label: 'RY', value: '${snapshot.rightStickY}'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '震动回调 ${snapshot.rumbleCount} 次 · '
              '低频 ${snapshot.lowFrequencyMotor} · '
              '高频 ${snapshot.highFrequencyMotor}',
              key: const Key('local-bridge-rumble'),
              style: const TextStyle(fontFamily: 'Consolas'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    ),
  );
}

class _RawCapturePanel extends StatelessWidget {
  const _RawCapturePanel({required this.snapshot});

  final InputCaptureSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xff071a19),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xff2dd4bf)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '原始状态 · ${snapshot.sampleCount} 个原生样本 · ${snapshot.state}',
              key: const Key('input-capture-status'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _RawMetric(label: 'Buttons', value: '0x${_hex(snapshot.buttonFlags, 8)}'),
                _RawMetric(label: 'LT', value: '${snapshot.leftTrigger}'),
                _RawMetric(label: 'RT', value: '${snapshot.rightTrigger}'),
                _RawMetric(label: 'LX', value: '${snapshot.leftStickX}'),
                _RawMetric(label: 'LY', value: '${snapshot.leftStickY}'),
                _RawMetric(label: 'RX', value: '${snapshot.rightStickX}'),
                _RawMetric(label: 'RY', value: '${snapshot.rightStickY}'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '观察范围  LT 0..${snapshot.leftTriggerMax}  '
              'RT 0..${snapshot.rightTriggerMax}\n'
              'LX ${snapshot.leftStickXMin}..${snapshot.leftStickXMax}  '
              'LY ${snapshot.leftStickYMin}..${snapshot.leftStickYMax}\n'
              'RX ${snapshot.rightStickXMin}..${snapshot.rightStickXMax}  '
              'RY ${snapshot.rightStickYMin}..${snapshot.rightStickYMax}\n'
              '已见按键 0x${_hex(snapshot.observedButtonFlags, 8)}',
              key: const Key('input-capture-ranges'),
              style: const TextStyle(fontFamily: 'Consolas', height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _RawMetric extends StatelessWidget {
  const _RawMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 105,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontFamily: 'Consolas')),
          ],
        ),
      ),
    ),
  );
}

String _hex(int value, int width) => value.toRadixString(16).toUpperCase().padLeft(width, '0');

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
