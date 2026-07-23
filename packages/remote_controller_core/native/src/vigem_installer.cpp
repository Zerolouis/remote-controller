// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#include "vigem_installer.h"

#include <algorithm>
#include <array>
#include <limits>
#include <string>
#include <vector>

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <Windows.h>
#include <bcrypt.h>
#include <shellapi.h>

namespace remote_controller {
namespace {

VigemInstallerLaunchResult Failure(const DWORD error) noexcept {
  return {false, static_cast<std::uint32_t>(error)};
}

constexpr std::uint64_t kInstallerSize = 6278576;
constexpr std::array<std::uint8_t, 32> kInstallerSha256{
    0x89, 0x22, 0x0A, 0x78, 0x65, 0x07, 0x6B, 0x34,
    0x28, 0x92, 0xF9, 0x88, 0x65, 0xF3, 0x49, 0x9F,
    0xB7, 0xC4, 0xCF, 0xD6, 0x73, 0x15, 0x9E, 0x89,
    0xD3, 0x52, 0xC3, 0x60, 0xFD, 0x01, 0x4C, 0x6A,
};

DWORD VerifyPinnedInstaller(const HANDLE file) {
  LARGE_INTEGER size{};
  if (!GetFileSizeEx(file, &size)) {
    return GetLastError();
  }
  if (size.QuadPart != static_cast<LONGLONG>(kInstallerSize)) {
    return ERROR_INVALID_DATA;
  }

  BCRYPT_ALG_HANDLE algorithm = nullptr;
  BCRYPT_HASH_HANDLE hash = nullptr;
  if (BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, nullptr,
                                  0) < 0) {
    return ERROR_GEN_FAILURE;
  }

  DWORD result = ERROR_GEN_FAILURE;
  DWORD object_length = 0;
  DWORD returned = 0;
  if (BCryptGetProperty(algorithm, BCRYPT_OBJECT_LENGTH,
                        reinterpret_cast<PUCHAR>(&object_length),
                        sizeof(object_length), &returned, 0) < 0) {
    BCryptCloseAlgorithmProvider(algorithm, 0);
    return result;
  }

  try {
    std::vector<std::uint8_t> hash_object(object_length);
    if (BCryptCreateHash(algorithm, &hash, hash_object.data(), object_length,
                         nullptr, 0, 0) < 0) {
      BCryptCloseAlgorithmProvider(algorithm, 0);
      return result;
    }

    std::array<std::uint8_t, 64 * 1024> buffer{};
    std::uint64_t total = 0;
    for (;;) {
      DWORD read = 0;
      if (!ReadFile(file, buffer.data(), static_cast<DWORD>(buffer.size()),
                    &read, nullptr)) {
        result = GetLastError();
        break;
      }
      if (read == 0) {
        std::array<std::uint8_t, 32> digest{};
        if (total == kInstallerSize &&
            BCryptFinishHash(hash, digest.data(),
                             static_cast<ULONG>(digest.size()), 0) >= 0 &&
            std::equal(digest.begin(), digest.end(),
                       kInstallerSha256.begin())) {
          result = ERROR_SUCCESS;
        } else {
          result = ERROR_INVALID_DATA;
        }
        break;
      }
      total += read;
      if (total > kInstallerSize ||
          BCryptHashData(hash, buffer.data(), read, 0) < 0) {
        result = ERROR_INVALID_DATA;
        break;
      }
    }

    BCryptDestroyHash(hash);
    BCryptCloseAlgorithmProvider(algorithm, 0);
    return result;
  } catch (...) {
    if (hash != nullptr) {
      BCryptDestroyHash(hash);
    }
    BCryptCloseAlgorithmProvider(algorithm, 0);
    return ERROR_NOT_ENOUGH_MEMORY;
  }
}

}  // namespace

VigemInstallerLaunchResult LaunchVigemInstaller(
    const std::string_view installer_path_utf8) {
  if (installer_path_utf8.empty()) {
    return Failure(ERROR_INVALID_PARAMETER);
  }

  try {
    if (installer_path_utf8.size() >
        static_cast<std::size_t>(std::numeric_limits<int>::max())) {
      return Failure(ERROR_FILENAME_EXCED_RANGE);
    }
    const auto utf8_length = static_cast<int>(installer_path_utf8.size());
    const int wide_length = MultiByteToWideChar(
        CP_UTF8, MB_ERR_INVALID_CHARS, installer_path_utf8.data(),
        utf8_length, nullptr, 0);
    if (wide_length <= 0) {
      return Failure(GetLastError());
    }

    std::wstring wide_path(static_cast<std::size_t>(wide_length), L'\0');
    if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                            installer_path_utf8.data(), utf8_length,
                            wide_path.data(), wide_length) != wide_length) {
      return Failure(GetLastError());
    }

    const DWORD required =
        GetFullPathNameW(wide_path.c_str(), 0, nullptr, nullptr);
    if (required == 0) {
      return Failure(GetLastError());
    }
    std::wstring full_path(static_cast<std::size_t>(required), L'\0');
    const DWORD full_length = GetFullPathNameW(
        wide_path.c_str(), required, full_path.data(), nullptr);
    if (full_length == 0 || full_length >= required) {
      return Failure(GetLastError());
    }
    full_path.resize(full_length);

    const HANDLE installer = CreateFileW(
        full_path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr,
        OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,
        nullptr);
    if (installer == INVALID_HANDLE_VALUE) {
      return Failure(GetLastError());
    }
    const DWORD verification_error = VerifyPinnedInstaller(installer);
    if (verification_error != ERROR_SUCCESS) {
      CloseHandle(installer);
      return Failure(verification_error);
    }

    SHELLEXECUTEINFOW execute_info{};
    execute_info.cbSize = sizeof(execute_info);
    execute_info.fMask =
        SEE_MASK_NOCLOSEPROCESS | SEE_MASK_NOASYNC | SEE_MASK_FLAG_NO_UI;
    execute_info.lpVerb = L"runas";
    execute_info.lpFile = full_path.c_str();
    execute_info.nShow = SW_SHOWNORMAL;
    if (!ShellExecuteExW(&execute_info)) {
      const DWORD error = GetLastError();
      CloseHandle(installer);
      return Failure(error);
    }
    if (execute_info.hProcess != nullptr) {
      CloseHandle(execute_info.hProcess);
    }
    CloseHandle(installer);
    return {true, ERROR_SUCCESS};
  } catch (...) {
    return Failure(ERROR_NOT_ENOUGH_MEMORY);
  }
}

}  // namespace remote_controller
