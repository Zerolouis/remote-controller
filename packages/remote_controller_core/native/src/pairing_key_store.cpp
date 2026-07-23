// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#include "pairing_key_store.h"

#include <chrono>
#include <cstdio>
#include <fstream>
#include <iterator>
#include <mutex>

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <Windows.h>
#include <bcrypt.h>

namespace remote_controller {
namespace {

constexpr std::uint32_t kMaxCode = 9999U;

std::mutex& StoreMutex() {
  static std::mutex mutex;
  return mutex;
}

}  // namespace

std::uint16_t PairingKeyStore::Generate() {
  std::uint32_t value = 0;
  if (BCryptGenRandom(nullptr, reinterpret_cast<PUCHAR>(&value), sizeof(value),
                      BCRYPT_USE_SYSTEM_PREFERRED_RNG) < 0) {
    value = static_cast<std::uint32_t>(
        std::chrono::steady_clock::now().time_since_epoch().count());
  }
  return static_cast<std::uint16_t>(value % (kMaxCode + 1U));
}

std::wstring PairingKeyStore::ResolvePath() {
  wchar_t override_buffer[MAX_PATH] = {};
  const DWORD override_length = GetEnvironmentVariableW(
      L"REMOTE_CONTROLLER_PAIRING_FILE", override_buffer, MAX_PATH);
  if (override_length > 0 && override_length < MAX_PATH) {
    return std::wstring(override_buffer, override_length);
  }
  wchar_t buffer[MAX_PATH] = {};
  const DWORD length = GetEnvironmentVariableW(L"APPDATA", buffer, MAX_PATH);
  if (length == 0 || length >= MAX_PATH) {
    return L"pairing_key.json";
  }
  std::wstring result(buffer, length);
  result += L"\\RemoteController";
  CreateDirectoryW(result.c_str(), nullptr);
  result += L"\\pairing_key.json";
  return result;
}

bool PairingKeyStore::ReadPersisted(std::uint16_t& out_key) {
  std::ifstream file(ResolvePath().c_str(), std::ios::binary);
  if (!file) {
    return false;
  }
  const std::string content((std::istreambuf_iterator<char>(file)),
                            std::istreambuf_iterator<char>());
  const auto key_pos = content.find("\"pairing_key\"");
  if (key_pos == std::string::npos) {
    return false;
  }
  const auto colon = content.find(':', key_pos);
  if (colon == std::string::npos) {
    return false;
  }
  std::uint32_t value = 0;
  bool any_digit = false;
  for (std::size_t i = colon + 1; i < content.size(); ++i) {
    const char c = content[i];
    if (c >= '0' && c <= '9') {
      value = value * 10U + static_cast<std::uint32_t>(c - '0');
      any_digit = true;
      if (value > kMaxCode) {
        return false;
      }
    } else if (any_digit) {
      break;
    } else if (c != ' ' && c != '\t' && c != '\r' && c != '\n') {
      break;
    }
  }
  if (!any_digit) {
    return false;
  }
  out_key = static_cast<std::uint16_t>(value);
  return true;
}

void PairingKeyStore::Persist(const std::uint16_t key) {
  std::ofstream file(ResolvePath().c_str(),
                     std::ios::binary | std::ios::trunc);
  if (!file) {
    return;
  }
  char buffer[64];
  std::snprintf(buffer, sizeof(buffer), "{\n  \"pairing_key\": %u\n}\n",
                static_cast<unsigned>(key));
  file << buffer;
}

std::uint16_t PairingKeyStore::Get() {
  std::lock_guard lock(StoreMutex());
  std::uint16_t key = 0;
  if (ReadPersisted(key)) {
    return key;
  }
  key = Generate();
  Persist(key);
  return key;
}

std::uint16_t PairingKeyStore::Regenerate() {
  std::lock_guard lock(StoreMutex());
  const std::uint16_t key = Generate();
  Persist(key);
  return key;
}

}  // namespace remote_controller
