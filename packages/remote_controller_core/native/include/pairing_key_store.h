// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#ifndef REMOTE_CONTROLLER_PAIRING_KEY_STORE_H_
#define REMOTE_CONTROLLER_PAIRING_KEY_STORE_H_

#include <cstdint>
#include <string>

namespace remote_controller {

// Generates and persists the 4-digit decimal pairing code that the trusted-LAN
// server uses to confirm a client actually meant to connect to it. The code is
// a user-visible confirmation value, NOT a secret: it is stored and transmitted
// in plain text and only prevents accidentally connecting to the wrong PC on a
// trusted LAN. It provides no confidentiality or strong authentication.
class PairingKeyStore final {
 public:
  PairingKeyStore() = delete;

  // Returns the persisted pairing key, generating and persisting it on first
  // use. The result is always in 0..9999.
  static std::uint16_t Get();

  // Generates a fresh pairing key, persists it and returns it. The previously
  // persisted key is replaced, so client history entries referencing the old
  // key will fail validation until re-entered.
  static std::uint16_t Regenerate();

 private:
  static std::uint16_t Generate();
  static bool ReadPersisted(std::uint16_t& out_key);
  static void Persist(std::uint16_t key);
  static std::wstring ResolvePath();
};

}  // namespace remote_controller

#endif  // REMOTE_CONTROLLER_PAIRING_KEY_STORE_H_
