// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#include "remote_controller_core.h"

#include "controller_protocol.h"

namespace {

constexpr std::uint32_t kAbiVersion = 1;
constexpr char kBuildInfo[] =
    "remote-controller-core/0.1.0; abi=1; protocol=1; backends=scaffold";

}  // namespace

extern "C" RC_API std::uint32_t rc_get_abi_version(void) { return kAbiVersion; }

extern "C" RC_API const char* rc_get_build_info(void) { return kBuildInfo; }
