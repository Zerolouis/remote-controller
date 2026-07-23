# Remote Controller

Remote Controller 是一个面向 Windows 掌机和 Windows PC 的开源局域网手柄转发项目。掌机端读取并临时独占实体手柄，PC 端创建虚拟 Xbox 手柄，并将震动反馈传回掌机。

当前仓库已进入 M2：Flutter Windows 界面、C/C++ Native Assets、自动生成的 FFI 绑定、SDL 3 实体手柄采集、ViGEm 虚拟 Xbox 360 输出、本机震动回传诊断、ViGEmBus 安装入口，以及首个 TCP 控制 + UDP 完整状态局域网诊断链路已经建立。该网络链路尚未配对或加密，只能在可信局域网测试；HidHide 和正式安全会话仍未接入。

## 范围

- 首要设备：ROG Ally X 内置手柄
- 单客户端、单手柄、局域网模式
- 标准 Xbox 按键、摇杆、扳机和震动
- 不处理音视频、桌面、键鼠、触摸板或原始 USB/HID 透传
- 不对摇杆和扳机应用死区或响应曲线

详细设计、上游源码分析和实施状态见 [项目知识库](docs/PROJECT_KNOWLEDGE.md)。

## 目录

```text
apps/remote_controller/            Flutter Windows 应用
packages/remote_controller_core/   Dart FFI 门面与 Windows C/C++ 核心
docs/                              架构与项目知识库
third_party/                       第三方来源和许可证记录
```

## 开发

需要 Flutter stable、Visual Studio C++ 桌面开发负载和 Windows SDK。进入核心包运行 FFIgen、分析和测试；进入 Flutter 应用运行分析、测试和 Windows 构建。详见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

GPL-3.0-only。第三方项目仍受各自许可证和版权声明约束，参见 [third_party/NOTICE.md](third_party/NOTICE.md)。驱动安装包不会随应用捆绑；ViGEmBus 仅在用户明确点击后从官方固定 URL 下载、校验并通过 Windows UAC 启动。
