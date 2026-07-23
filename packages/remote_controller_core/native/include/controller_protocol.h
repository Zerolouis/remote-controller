// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#ifndef REMOTE_CONTROLLER_PROTOCOL_H_
#define REMOTE_CONTROLLER_PROTOCOL_H_

#include <array>
#include <cstdint>
#include <type_traits>

namespace remote_controller::protocol {

inline constexpr std::uint32_t kInputMagic = 0x31494352;  // "RCI1" in LE.
inline constexpr std::uint8_t kProtocolVersion = 1;
inline constexpr std::uint16_t kInputDatagramSize = 64;
inline constexpr std::uint16_t kInputHeaderSize = 32;
inline constexpr std::uint16_t kControlPort = 26760;
inline constexpr std::uint16_t kInputPort = 26760;
inline constexpr std::uint16_t kDiscoveryPort = 26761;
inline constexpr std::uint16_t kInputFlagTrustedLanPlaintext = 0x0001;
inline constexpr std::uint32_t kControlMagic = 0x31434352;  // "RCC1" in LE.
inline constexpr std::uint16_t kControlFrameSize = 32;

// Reason codes carried in the `sequence` field of a kError control frame.
inline constexpr std::uint64_t kControlErrorPairingKeyMismatch = 1;

// Sentinel stored in snapshot last_error when a LAN handshake fails because the
// client presented a wrong pairing key. Deliberately outside the Winsock range.
inline constexpr std::uint32_t kPairingKeyMismatchError = 0x52430001;  // "RC"|1

enum class MessageType : std::uint8_t {
  kFullState = 1,
  kRumble = 2,
  kHeartbeat = 3,
};

enum class ControlMessageType : std::uint8_t {
  kHello = 1,
  kHelloAck = 2,
  kHeartbeat = 3,
  kRumble = 4,
  kStop = 5,
  kError = 6,
};

enum ButtonFlag : std::uint32_t {
  kDpadUp = 0x0001,
  kDpadDown = 0x0002,
  kDpadLeft = 0x0004,
  kDpadRight = 0x0008,
  kStart = 0x0010,
  kBack = 0x0020,
  kLeftStick = 0x0040,
  kRightStick = 0x0080,
  kLeftShoulder = 0x0100,
  kRightShoulder = 0x0200,
  kGuide = 0x0400,
  kA = 0x1000,
  kB = 0x2000,
  kX = 0x4000,
  kY = 0x8000,
  kPaddle1 = 0x010000,
  kPaddle2 = 0x020000,
  kPaddle3 = 0x040000,
  kPaddle4 = 0x080000,
  kTouchpadButton = 0x100000,
  kMiscButton = 0x200000,
};

#pragma pack(push, 1)

struct InputPacketHeaderV1 {
  std::uint32_t magic;
  std::uint8_t version;
  std::uint8_t message_type;
  std::uint16_t flags;
  std::uint16_t packet_length;
  std::uint16_t header_length;
  std::uint32_t session_id;
  std::uint64_t sequence;
  std::uint64_t timestamp_us;
};

struct GamepadStateV1 {
  std::uint32_t button_flags;
  std::uint16_t left_trigger;
  std::uint16_t right_trigger;
  std::int16_t left_stick_x;
  std::int16_t left_stick_y;
  std::int16_t right_stick_x;
  std::int16_t right_stick_y;
};

// In the encrypted wire representation, encrypted_state is AEAD ciphertext.
struct InputDatagramV1 {
  InputPacketHeaderV1 header;
  std::array<std::uint8_t, sizeof(GamepadStateV1)> encrypted_state;
  std::array<std::uint8_t, 16> authentication_tag;
};

// Trusted-LAN MVP control frame. It deliberately has no encryption and must
// not be exposed to untrusted or internet-routed networks.
struct PlaintextControlFrameV1 {
  std::uint32_t magic;
  std::uint8_t version;
  std::uint8_t message_type;
  std::uint16_t flags;
  std::uint16_t frame_length;
  // 4-digit decimal pairing code (0..9999). Only meaningful in kHello; 0 in
  // every other message type. Plain-text confirmation code, not a secret.
  std::uint16_t pairing_key;
  std::uint32_t session_id;
  std::uint64_t sequence;
  std::uint16_t low_frequency_motor;
  std::uint16_t high_frequency_motor;
  std::uint32_t capabilities;
};

#pragma pack(pop)

static_assert(sizeof(InputPacketHeaderV1) == kInputHeaderSize);
static_assert(sizeof(GamepadStateV1) == 16);
static_assert(sizeof(InputDatagramV1) == kInputDatagramSize);
static_assert(sizeof(PlaintextControlFrameV1) == kControlFrameSize);
static_assert(std::is_trivially_copyable_v<GamepadStateV1>);

}  // namespace remote_controller::protocol

#endif  // REMOTE_CONTROLLER_PROTOCOL_H_
