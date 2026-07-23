// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

enum AppRole { client, server }

extension AppRoleLabel on AppRole {
  String get title => switch (this) {
    AppRole.client => '掌机客户端',
    AppRole.server => '电脑服务端',
  };

  String get description => switch (this) {
    AppRole.client => '读取掌机手柄，将完整原始状态发送到可信局域网电脑。',
    AppRole.server => '接收手柄状态，创建虚拟 Xbox 手柄并回传震动。',
  };
}
