# Remote Controller

Remote Controller 是一个面向 Windows 掌机和 Windows PC 的开源局域网手柄转发项目。掌机端读取并临时独占实体手柄，PC 端创建虚拟 Xbox 手柄，并将震动反馈传回掌机。

当前仓库处于 M1 阶段：Flutter Windows 界面、C/C++ Native Assets、自动生成的 FFI 绑定、SDL 3 实体手柄采集、ViGEm 虚拟 Xbox 360 输出和本机震动回传诊断已经建立；HidHide、加密局域网传输和正式 Client/Server 会话尚未接入。

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

GPL-3.0-only。第三方项目仍受各自许可证和版权声明约束，参见 [third_party/NOTICE.md](third_party/NOTICE.md)。驱动安装包不会随本项目重新分发。
