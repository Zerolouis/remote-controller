// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#ifndef REMOTE_CONTROLLER_VIGEM_INSTALLER_H_
#define REMOTE_CONTROLLER_VIGEM_INSTALLER_H_

#include <cstdint>
#include <string_view>

namespace remote_controller {

struct VigemInstallerLaunchResult {
  bool launched{};
  std::uint32_t win32_error{};
};

VigemInstallerLaunchResult LaunchVigemInstaller(
    std::string_view installer_path_utf8);

}  // namespace remote_controller

#endif  // REMOTE_CONTROLLER_VIGEM_INSTALLER_H_
