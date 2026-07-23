# Remote Controller

Remote Controller 是一个面向 Windows 掌机和 Windows PC 的开源局域网手柄转发项目。掌机端读取实体手柄，PC 端创建虚拟 Xbox 手柄，并将震动反馈传回掌机。

当前可信局域网 MVP 已可运行：Flutter Windows 界面、C/C++ Native Assets、自动生成的 FFI 绑定、SDL 3 实体手柄采集、ViGEm 虚拟 Xbox 360 输出、ViGEmBus 安装入口，以及 TCP 控制 + UDP 完整状态局域网链路均已建立。该网络链路未配对或加密，只适用于用户信任的家庭或个人局域网。

## 范围

- 首要设备：ROG Ally X 内置手柄
- 单客户端、单手柄、局域网模式
- 标准 Xbox 按键、摇杆、扳机和震动
- 不处理音视频、桌面、键鼠、触摸板或原始 USB/HID 透传
- 不对摇杆和扳机应用死区或响应曲线
- 不隐藏掌机实体手柄；需要时由用户自行关闭掌机上的冲突程序

详细设计、上游源码分析和实施状态见 [项目知识库](docs/PROJECT_KNOWLEDGE.md)。

## 目录

```text
apps/remote_controller/            Flutter Windows 应用
packages/remote_controller_core/   Dart FFI 门面与 Windows C/C++ 核心
docs/                              架构与项目知识库
third_party/                       第三方来源和许可证记录
```

## 开发

需要 Flutter stable、Visual Studio C++ 桌面开发负载和 Windows SDK。进入核心包运行 FFIgen、分析和测试；进入 Flutter 应用运行分析、测试和 Windows 构建。双机验收与发布步骤见 [发布检查清单](docs/RELEASE_CHECKLIST.md)，开发约定见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

GPL-3.0-only。第三方项目仍受各自许可证和版权声明约束，参见 [third_party/NOTICE.md](third_party/NOTICE.md)。驱动安装包不会随应用捆绑；ViGEmBus 仅在用户明确点击后从官方固定 URL 下载、校验并通过 Windows UAC 启动。
