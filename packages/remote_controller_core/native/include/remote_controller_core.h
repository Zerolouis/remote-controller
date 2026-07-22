// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#ifndef REMOTE_CONTROLLER_CORE_H_
#define REMOTE_CONTROLLER_CORE_H_

#include <stdint.h>

#if defined(_WIN32)
#if defined(RC_BUILDING_DLL)
#define RC_API __declspec(dllexport)
#else
#define RC_API __declspec(dllimport)
#endif
#else
#define RC_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

// ABI version for the exported C interface. Increase only for breaking changes.
RC_API uint32_t rc_get_abi_version(void);

// Returns a process-lifetime UTF-8 string owned by the native library.
RC_API const char* rc_get_build_info(void);

#ifdef __cplusplus
}
#endif

#endif  // REMOTE_CONTROLLER_CORE_H_
