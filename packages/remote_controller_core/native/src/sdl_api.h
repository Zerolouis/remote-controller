// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

#ifndef REMOTE_CONTROLLER_SDL_API_H_
#define REMOTE_CONTROLLER_SDL_API_H_

#include <cstdint>
#include <mutex>
#include <string>

#include <SDL3/SDL.h>

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <Windows.h>

namespace remote_controller::sdl {

class Api final {
 public:
  static Api& Instance();

  bool EnsureInitialized();
  std::string Error() const;
  std::uint32_t Version() const;
  std::string Revision() const;

  decltype(&SDL_GetGamepads) get_gamepads{};
  decltype(&SDL_free) free_memory{};
  decltype(&SDL_GetGamepadNameForID) get_gamepad_name_for_id{};
  decltype(&SDL_GetGamepadPathForID) get_gamepad_path_for_id{};
  decltype(&SDL_GetGamepadGUIDForID) get_gamepad_guid_for_id{};
  decltype(&SDL_GUIDToString) guid_to_string{};
  decltype(&SDL_GetGamepadVendorForID) get_gamepad_vendor_for_id{};
  decltype(&SDL_GetGamepadProductForID) get_gamepad_product_for_id{};
  decltype(&SDL_GetGamepadProductVersionForID)
      get_gamepad_product_version_for_id{};
  decltype(&SDL_GetGamepadTypeForID) get_gamepad_type_for_id{};
  decltype(&SDL_OpenGamepad) open_gamepad{};
  decltype(&SDL_CloseGamepad) close_gamepad{};
  decltype(&SDL_GamepadConnected) gamepad_connected{};
  decltype(&SDL_GetGamepadConnectionState) get_gamepad_connection_state{};
  decltype(&SDL_GamepadHasButton) gamepad_has_button{};
  decltype(&SDL_GamepadHasAxis) gamepad_has_axis{};
  decltype(&SDL_GetGamepadProperties) get_gamepad_properties{};
  decltype(&SDL_GetBooleanProperty) get_boolean_property{};
  decltype(&SDL_UpdateGamepads) update_gamepads{};
  decltype(&SDL_GetGamepadButton) get_gamepad_button{};
  decltype(&SDL_GetGamepadAxis) get_gamepad_axis{};

 private:
  Api() = default;

  void Initialize() noexcept;

  template <typename T>
  bool Resolve(T& target, const char* name) noexcept {
    target = reinterpret_cast<T>(GetProcAddress(module_, name));
    if (target == nullptr) {
      error_ = std::string("SDL3.dll is missing symbol ") + name + '.';
      return false;
    }
    return true;
  }

  std::once_flag initialize_once_;
  HMODULE module_{nullptr};
  bool initialized_{false};
  std::string error_;
  std::uint32_t version_{};
  std::string revision_;
};

}  // namespace remote_controller::sdl

#endif  // REMOTE_CONTROLLER_SDL_API_H_
