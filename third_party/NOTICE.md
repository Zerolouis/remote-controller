# Third-party notices

This repository contains original compatibility-oriented implementation plus small reviewed controller-path adaptations identified below. Complete upstream source trees are not vendored.

| Project | Revision / version reviewed | License | Intended use |
|---|---|---|---|
| LizardByte/Sunshine | `93fc98394f4edd492e21d25b5833d29cef4123cc` | GPL-3.0 | Windows input injection, controller lifecycle and rumble design reference |
| moonlight-stream/moonlight-qt | `2328713f4e7b8442e6bd49238b4eba27031a4d9f` | GPL-3.0 | Client controller polling/mapping reference |
| moonlight-stream/moonlight-common-c | `703a06946861ff82cd33e5e13c59c1b017f7ded9` | GPL-3.0 | Button masks, controller packets and capability negotiation reference |
| LizardByte/Virtual-Gamepad-Emulation-Client | `8d71f6740ffff4671cdadbca255ce528e3cd3fef` | MIT | Candidate virtual Xbox controller client API |
| nefarius/ViGEmBus | 1.22.0 | BSD-3-Clause | External virtual gamepad driver; not redistributed |
| nefarius/HidHide | `2b950fd9393e1644b4199f6eb4999e1720f0c6e9` | MIT | External device hiding driver and configuration contract; not redistributed |
| libsdl-org/SDL | 3.4.12 / `f87239e71e42da91ca317a12eefb82cfbf3393eb` | zlib | Physical controller headers and bundled Windows runtime |
| Moonlight ENet fork | `aca87840b57f045a1f7f9299e4b1b9b8e2a5e2f1` | MIT | Candidate reliable UDP transport reference |

## Imported or adapted controller-path material

| Upstream source | Destination | Use and modifications |
|---|---|---|
| moonlight-qt `app/streaming/input/gamepad.cpp` at `2328713f4e7b8442e6bd49238b4eba27031a4d9f` | `packages/remote_controller_core/native/src/sdl_input_backend.cpp` | Adapted the standard SDL button-to-Moonlight mask ordering to SDL 3 and this project's 32-bit full-state model; Qt, streaming, shortcuts, and audio/video code were not imported. |
| Sunshine `src/platform/common.h` at `93fc98394f4edd492e21d25b5833d29cef4123cc` | `packages/remote_controller_core/native/include/controller_protocol.h` and `native/src/sdl_input_backend.cpp` | Reused GPL-3.0 controller button bit values, including paddles, touchpad, and misc extensions. |

## SDL binary dependency

- Official VC SDK asset: `SDL3-devel-3.4.12-VC.zip`
- Download URL: `https://github.com/libsdl-org/SDL/releases/download/release-3.4.12/SDL3-devel-3.4.12-VC.zip`
- Archive SHA-256: `8793a153c7eba93b1eb8022fd2356383ec446b2584e43724a72ef68d682813ab`
- Upstream source revision: `f87239e71e42da91ca317a12eefb82cfbf3393eb`
- Build behavior: the Native Assets hook verifies the archive, extracts only headers, the target-architecture `SDL3.dll`, and `LICENSE.txt`, then bundles `SDL3.dll` beside the application. A local extracted official SDK can be selected with the `sdl_sdk_path` hook user define.
- License copy: `third_party/sdl/LICENSE.txt`.

Future imported code must record the exact source path, revision, original copyright text, modifications, and destination file here.
