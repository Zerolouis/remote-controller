# Windows MVP 发布检查清单

Remote Controller 首版面向一台 Windows 掌机 Client 和一台 Windows PC Server。网络协议未加密，只支持用户信任的家庭或个人局域网。

## 1. 构建环境

- Windows 11 x64
- Flutter `3.44.7` stable / Dart `3.12.2`
- Visual Studio 2022 Desktop development with C++
- Windows 10/11 SDK
- LLVM/libclang（仅重新生成 FFI 绑定时需要）

## 2. 提交前检查

在 `packages/remote_controller_core` 执行：

```powershell
flutter pub get
dart run tool/ffigen.dart
git diff --exit-code -- lib/src/third_party/remote_controller_core.g.dart lib/src/third_party/remote_controller_core.record_use_mapping.g.dart
flutter analyze --fatal-infos
flutter test
```

在 `apps/remote_controller` 执行：

```powershell
flutter pub get
flutter analyze --fatal-infos
flutter test
flutter build windows --release
```

中文 Visual Studio 环境若 `dart run tool/ffigen.dart` 触发 `vswhere` 解码问题，可直接使用 Flutter 内置 Dart VM：

```powershell
& "$env:FLUTTER_ROOT\bin\cache\dart-sdk\bin\dart.exe" --packages=.dart_tool/package_config.json tool/ffigen.dart
```

## 3. Release 目录检查

目标目录：

```text
apps/remote_controller/build/windows/x64/runner/Release/
```

必须包含：

- `remote_controller.exe`
- `remote_controller_core.dll`
- `SDL3.dll`
- Flutter Windows 运行库和 `data/`

不得包含：

- `ViGEmBus_*.exe`
- `ViGEmClient.dll`
- Sunshine、Moonlight 或 ViGEmClient 完整源码树
- 本地 `.research/`、日志或临时缓存

生成发布压缩包后记录 SHA-256：

```powershell
Get-FileHash .\remote-controller-windows-x64.zip -Algorithm SHA256
```

## 4. 双机验收

PC Server：

1. 启动“电脑服务端”。
2. 确认 ViGEmBus 可用；缺失时验证下载、SHA-256、UAC 取消和安装后重新检测。
3. 点击“监听 TCP/UDP 26760”。
4. Windows 防火墙仅允许专用网络。

ROG Ally X Client：

1. 启动“掌机客户端”并扫描 SDL 手柄。
2. 确认识别 `VID 0B05 / PID 1B4C`，原始值页面约为 250 Hz。
3. 输入 PC 的局域网 IPv4 地址，点击“发送到电脑”。
4. 使用 `joy.cpl` 或游戏检查所有按钮、双摇杆和双扳机。
5. 确认摇杆、扳机没有应用层死区、曲线或平滑。
6. 在支持 XInput 震动的游戏中检查双马达反馈返回掌机。

安全释放：

1. 按住按钮时正常停止 Client，PC 必须立即恢复中立状态并移除 target。
2. 按住按钮时断开 Wi-Fi/网线，PC 应在约 100 ms 输入 watchdog 或更早的 TCP 断开路径归零。
3. 快速重新启动 Server 和 Client，旧 session/sequence 不得恢复旧按键。
4. 持续运行至少 30 分钟，确认无卡键、崩溃或不断增长的错误/丢弃计数。

## 5. 已接受的首版限制

- 不隐藏掌机实体手柄；用户需要自行关闭掌机上的冲突程序。
- 只支持可信 LAN，协议没有身份认证或加密。
- 只支持 IPv4、单客户端、单手柄和单个虚拟 X360 target。
- 不支持音视频、桌面、键鼠、触摸板、原始 USB/HID 透传或互联网中继。
- ViGEmBus 已归档，长期需要保留可替换的 `VirtualControllerBackend`。

## 6. 开源发布检查

- 根目录 `LICENSE` 为 GPL-3.0-only。
- 所有新增源码保留 SPDX 标识。
- `third_party/NOTICE.md`、SDL、ViGEmClient 和 ViGEmBus 许可证随源码发布。
- 发布对应的完整源码提交或源码归档，保留第三方源码获取方式和固定修订信息。
- Release notes 明示“可信 LAN、未加密”和“不隐藏 Client 实体手柄”。
