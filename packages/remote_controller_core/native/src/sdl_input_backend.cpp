// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#include "backends/sdl_input_backend.h"

#include <algorithm>
#include <array>
#include <charconv>
#include <chrono>
#include <cstdint>
#include <limits>
#include <string_view>
#include <utility>

#include "controller_protocol.h"
#include "sdl_api.h"

namespace remote_controller::sdl {
namespace {

std::wstring CoreModuleDirectory() {
  HMODULE module = nullptr;
  const auto address = reinterpret_cast<LPCWSTR>(&CoreModuleDirectory);
  if (GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                             GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                         address, &module) == 0) {
    return {};
  }

  std::wstring path(32768, L'\0');
  const DWORD length = GetModuleFileNameW(
      module, path.data(), static_cast<DWORD>(path.size()));
  if (length == 0 || length >= path.size()) {
    return {};
  }
  path.resize(length);
  const auto separator = path.find_last_of(L"\\/");
  return separator == std::wstring::npos ? std::wstring{} :
                                           path.substr(0, separator + 1);
}

}  // namespace

Api& Api::Instance() {
  static Api api;
  return api;
}

bool Api::EnsureInitialized() {
  std::call_once(initialize_once_, [this] { Initialize(); });
  return initialized_;
}

std::string Api::Error() const { return error_; }

std::uint32_t Api::Version() const { return version_; }

std::string Api::Revision() const { return revision_; }

void Api::Initialize() noexcept {
  const auto directory = CoreModuleDirectory();
  const auto dll_path = directory + L"SDL3.dll";
  module_ = LoadLibraryExW(
      dll_path.c_str(), nullptr,
      LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
  if (module_ == nullptr) {
    error_ = "SDL3.dll was not found next to remote_controller_core.dll.";
    return;
  }

  decltype(&SDL_GetVersion) get_version = nullptr;
  decltype(&SDL_GetRevision) get_revision = nullptr;
  decltype(&SDL_InitSubSystem) init_subsystem = nullptr;
  decltype(&SDL_GetError) get_error = nullptr;
  decltype(&SDL_SetGamepadEventsEnabled) set_gamepad_events_enabled = nullptr;

  const bool resolved =
      Resolve(get_version, "SDL_GetVersion") &&
      Resolve(get_revision, "SDL_GetRevision") &&
      Resolve(init_subsystem, "SDL_InitSubSystem") &&
      Resolve(get_error, "SDL_GetError") &&
      Resolve(set_gamepad_events_enabled, "SDL_SetGamepadEventsEnabled") &&
      Resolve(get_gamepads, "SDL_GetGamepads") &&
      Resolve(free_memory, "SDL_free") &&
      Resolve(get_gamepad_name_for_id, "SDL_GetGamepadNameForID") &&
      Resolve(get_gamepad_path_for_id, "SDL_GetGamepadPathForID") &&
      Resolve(get_gamepad_guid_for_id, "SDL_GetGamepadGUIDForID") &&
      Resolve(guid_to_string, "SDL_GUIDToString") &&
      Resolve(get_gamepad_vendor_for_id, "SDL_GetGamepadVendorForID") &&
      Resolve(get_gamepad_product_for_id, "SDL_GetGamepadProductForID") &&
      Resolve(get_gamepad_product_version_for_id,
              "SDL_GetGamepadProductVersionForID") &&
      Resolve(get_gamepad_type_for_id, "SDL_GetGamepadTypeForID") &&
      Resolve(open_gamepad, "SDL_OpenGamepad") &&
      Resolve(close_gamepad, "SDL_CloseGamepad") &&
      Resolve(gamepad_connected, "SDL_GamepadConnected") &&
      Resolve(get_gamepad_connection_state,
              "SDL_GetGamepadConnectionState") &&
      Resolve(gamepad_has_button, "SDL_GamepadHasButton") &&
      Resolve(gamepad_has_axis, "SDL_GamepadHasAxis") &&
      Resolve(get_gamepad_properties, "SDL_GetGamepadProperties") &&
      Resolve(get_boolean_property, "SDL_GetBooleanProperty") &&
      Resolve(update_gamepads, "SDL_UpdateGamepads") &&
      Resolve(get_gamepad_button, "SDL_GetGamepadButton") &&
      Resolve(get_gamepad_axis, "SDL_GetGamepadAxis");
  if (!resolved) {
    return;
  }

  version_ = static_cast<std::uint32_t>(get_version());
  if (version_ != SDL_VERSIONNUM(3, 4, 12)) {
    error_ = "The bundled SDL runtime is not the pinned version 3.4.12.";
    return;
  }
  const char* revision = get_revision();
  revision_ = revision == nullptr ? std::string{} : revision;

  if (!init_subsystem(SDL_INIT_GAMEPAD)) {
    const char* error = get_error();
    error_ = error == nullptr ? "SDL gamepad initialization failed." : error;
    return;
  }
  set_gamepad_events_enabled(false);
  initialized_ = true;
}

}  // namespace remote_controller::sdl

namespace remote_controller::backends {
namespace {

constexpr std::uint16_t kAsusVendorId = 0x0B05;
constexpr std::uint16_t kRogAllyXProductId = 0x1B4C;
constexpr auto kPollingPeriod = std::chrono::milliseconds(4);

// The standard-button order follows Moonlight Qt's k_ButtonMap and the bit
// values follow Sunshine platform/common.h. Both upstream files are GPL-3.0.
constexpr std::array<std::pair<SDL_GamepadButton, std::uint32_t>, 21>
    kButtonMap{{
        {SDL_GAMEPAD_BUTTON_SOUTH, protocol::kA},
        {SDL_GAMEPAD_BUTTON_EAST, protocol::kB},
        {SDL_GAMEPAD_BUTTON_WEST, protocol::kX},
        {SDL_GAMEPAD_BUTTON_NORTH, protocol::kY},
        {SDL_GAMEPAD_BUTTON_BACK, protocol::kBack},
        {SDL_GAMEPAD_BUTTON_GUIDE, protocol::kGuide},
        {SDL_GAMEPAD_BUTTON_START, protocol::kStart},
        {SDL_GAMEPAD_BUTTON_LEFT_STICK, protocol::kLeftStick},
        {SDL_GAMEPAD_BUTTON_RIGHT_STICK, protocol::kRightStick},
        {SDL_GAMEPAD_BUTTON_LEFT_SHOULDER, protocol::kLeftShoulder},
        {SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER, protocol::kRightShoulder},
        {SDL_GAMEPAD_BUTTON_DPAD_UP, protocol::kDpadUp},
        {SDL_GAMEPAD_BUTTON_DPAD_DOWN, protocol::kDpadDown},
        {SDL_GAMEPAD_BUTTON_DPAD_LEFT, protocol::kDpadLeft},
        {SDL_GAMEPAD_BUTTON_DPAD_RIGHT, protocol::kDpadRight},
        {SDL_GAMEPAD_BUTTON_MISC1, protocol::kMiscButton},
        {SDL_GAMEPAD_BUTTON_RIGHT_PADDLE1, protocol::kPaddle1},
        {SDL_GAMEPAD_BUTTON_LEFT_PADDLE1, protocol::kPaddle2},
        {SDL_GAMEPAD_BUTTON_RIGHT_PADDLE2, protocol::kPaddle3},
        {SDL_GAMEPAD_BUTTON_LEFT_PADDLE2, protocol::kPaddle4},
        {SDL_GAMEPAD_BUTTON_TOUCHPAD, protocol::kTouchpadButton},
    }};

std::uint32_t ReadButtons(sdl::Api& api, SDL_Gamepad* gamepad) {
  std::uint32_t flags = 0;
  for (const auto& [button, flag] : kButtonMap) {
    if (api.get_gamepad_button(gamepad, button)) {
      flags |= flag;
    }
  }
  return flags;
}

std::uint32_t SupportedButtons(sdl::Api& api, SDL_Gamepad* gamepad) {
  std::uint32_t flags = 0;
  for (const auto& [button, flag] : kButtonMap) {
    if (api.gamepad_has_button(gamepad, button)) {
      flags |= flag;
    }
  }
  return flags;
}

std::uint16_t NormalizeTrigger(const std::int16_t value) {
  if (value <= 0) {
    return 0;
  }
  return static_cast<std::uint16_t>(
      (static_cast<std::uint32_t>(value) * 65535U + 16383U) / 32767U);
}

std::int16_t InvertYAxis(const std::int16_t value) {
  return value == std::numeric_limits<std::int16_t>::min()
             ? std::numeric_limits<std::int16_t>::max()
             : static_cast<std::int16_t>(-value);
}

protocol::GamepadStateV1 ReadState(sdl::Api& api, SDL_Gamepad* gamepad) {
  return {
      ReadButtons(api, gamepad),
      NormalizeTrigger(
          api.get_gamepad_axis(gamepad, SDL_GAMEPAD_AXIS_LEFT_TRIGGER)),
      NormalizeTrigger(
          api.get_gamepad_axis(gamepad, SDL_GAMEPAD_AXIS_RIGHT_TRIGGER)),
      api.get_gamepad_axis(gamepad, SDL_GAMEPAD_AXIS_LEFTX),
      InvertYAxis(api.get_gamepad_axis(gamepad, SDL_GAMEPAD_AXIS_LEFTY)),
      api.get_gamepad_axis(gamepad, SDL_GAMEPAD_AXIS_RIGHTX),
      InvertYAxis(api.get_gamepad_axis(gamepad, SDL_GAMEPAD_AXIS_RIGHTY)),
  };
}

}  // namespace

SdlInputBackend::~SdlInputBackend() { Close(); }

SdlRuntimeInfo SdlInputBackend::GetRuntimeInfo() {
  auto& api = sdl::Api::Instance();
  const bool available = api.EnsureInitialized();
  return {available, api.Version(), api.Revision(), api.Error()};
}

std::vector<InputDeviceInfo> SdlInputBackend::EnumerateDevices() {
  auto& api = sdl::Api::Instance();
  if (!api.EnsureInitialized()) {
    return {};
  }

  int count = 0;
  SDL_JoystickID* ids = api.get_gamepads(&count);
  if (ids == nullptr) {
    return {};
  }

  std::vector<InputDeviceInfo> devices;
  devices.reserve(static_cast<std::size_t>(std::max(count, 0)));
  for (int index = 0; index < count; ++index) {
    const SDL_JoystickID instance_id = ids[index];
    InputDeviceInfo info;
    info.id = std::to_string(instance_id);
    const char* name = api.get_gamepad_name_for_id(instance_id);
    const char* path = api.get_gamepad_path_for_id(instance_id);
    info.display_name = name == nullptr ? "Unknown SDL gamepad" : name;
    info.device_path = path == nullptr ? std::string{} : path;
    info.vendor_id = api.get_gamepad_vendor_for_id(instance_id);
    info.product_id = api.get_gamepad_product_for_id(instance_id);
    info.product_version =
        api.get_gamepad_product_version_for_id(instance_id);
    info.controller_type = static_cast<std::uint32_t>(
        api.get_gamepad_type_for_id(instance_id));
    if (info.vendor_id == kAsusVendorId &&
        info.product_id == kRogAllyXProductId) {
      info.flags |= kRogAllyX;
    }

    std::array<char, 33> guid{};
    api.guid_to_string(api.get_gamepad_guid_for_id(instance_id), guid.data(),
                       static_cast<int>(guid.size()));
    info.guid = guid.data();

    SDL_Gamepad* gamepad = api.open_gamepad(instance_id);
    if (gamepad != nullptr) {
      info.connection_state = static_cast<std::int32_t>(
          api.get_gamepad_connection_state(gamepad));
      info.supported_buttons = SupportedButtons(api, gamepad);
      if (api.gamepad_has_axis(gamepad, SDL_GAMEPAD_AXIS_LEFT_TRIGGER) ||
          api.gamepad_has_axis(gamepad, SDL_GAMEPAD_AXIS_RIGHT_TRIGGER)) {
        info.capabilities |= kAnalogTriggers;
      }
      const SDL_PropertiesID properties = api.get_gamepad_properties(gamepad);
      if (api.get_boolean_property(
              properties, SDL_PROP_GAMEPAD_CAP_RUMBLE_BOOLEAN, false)) {
        info.capabilities |= kRumble;
      }
      if (api.get_boolean_property(
              properties, SDL_PROP_GAMEPAD_CAP_TRIGGER_RUMBLE_BOOLEAN,
              false)) {
        info.capabilities |= kTriggerRumble;
      }
      api.close_gamepad(gamepad);
    }
    devices.push_back(std::move(info));
  }
  api.free_memory(ids);
  return devices;
}

bool SdlInputBackend::Open(const std::string& device_id,
                           StateCallback state_callback,
                           DisconnectCallback disconnect_callback) {
  auto& api = sdl::Api::Instance();
  if (!api.EnsureInitialized() || !state_callback) {
    return false;
  }

  std::uint32_t parsed_id = 0;
  const auto [end, error] = std::from_chars(
      device_id.data(), device_id.data() + device_id.size(), parsed_id);
  if (error != std::errc{} || end != device_id.data() + device_id.size()) {
    return false;
  }

  std::lock_guard lock(mutex_);
  if (gamepad_ != nullptr || poll_thread_.joinable()) {
    return false;
  }
  gamepad_ = api.open_gamepad(static_cast<SDL_JoystickID>(parsed_id));
  if (gamepad_ == nullptr) {
    return false;
  }
  state_callback_ = std::move(state_callback);
  disconnect_callback_ = std::move(disconnect_callback);
  stop_requested_ = false;
  poll_thread_ = std::thread(&SdlInputBackend::PollLoop, this);
  return true;
}

void SdlInputBackend::Close() noexcept {
  stop_requested_ = true;
  if (poll_thread_.joinable()) {
    poll_thread_.join();
  }

  std::lock_guard lock(mutex_);
  if (gamepad_ != nullptr) {
    sdl::Api::Instance().close_gamepad(gamepad_);
    gamepad_ = nullptr;
  }
  state_callback_ = {};
  disconnect_callback_ = {};
}

void SdlInputBackend::PollLoop() noexcept {
  SDL_Gamepad* gamepad = nullptr;
  StateCallback state_callback;
  DisconnectCallback disconnect_callback;
  {
    std::lock_guard lock(mutex_);
    gamepad = gamepad_;
    state_callback = state_callback_;
    disconnect_callback = disconnect_callback_;
  }

  auto& api = sdl::Api::Instance();
  auto next_poll = std::chrono::steady_clock::now();
  while (!stop_requested_) {
    api.update_gamepads();
    if (!api.gamepad_connected(gamepad)) {
      if (!stop_requested_ && disconnect_callback) {
        disconnect_callback();
      }
      return;
    }
    state_callback(ReadState(api, gamepad));

    next_poll += kPollingPeriod;
    const auto now = std::chrono::steady_clock::now();
    if (next_poll < now) {
      next_poll = now;
    }
    std::this_thread::sleep_until(next_poll);
  }
}

}  // namespace remote_controller::backends
