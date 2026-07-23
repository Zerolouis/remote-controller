## 0.6.0

- Add a Windows UDP LAN `TransportBackend` with a separate reliable TCP control and rumble channel.
- Add native Client SDL-to-network and Server network-to-ViGEm session coordinators with sequence validation and a 100 ms neutral watchdog.
- Add generated FFI session APIs, Flutter diagnostics, packet statistics, and an end-to-end localhost protocol test.
- Mark the initial network path as plaintext trusted-LAN diagnostics pending pairing and AEAD.

## 0.5.0

- Add a generated C/Dart ABI for launching an authenticated ViGEmBus installer through Windows UAC.
- Keep installer execution outside the Flutter UI isolate and return the Win32 launch result for diagnostics.
- Re-verify the pinned installer with Windows BCrypt while holding it against modification, then use the Windows Shell API to show UAC.

## 0.4.0

- Pin the reviewed Sunshine ViGEmClient fork and compile its minimal X360 client source through Native Assets.
- Add ViGEmBus probing, a single virtual Xbox 360 target, full-state mapping, and rumble callbacks.
- Add a native SDL-to-ViGEm diagnostic bridge with Flutter controls and 10 Hz snapshots.
- Preserve 16-bit trigger values until deterministic 8-bit X360 report quantization.

## 0.3.0

- Pin SDL 3.4.12 and bundle its official Windows runtime through Native Assets.
- Add SDL gamepad enumeration, capability reporting, and exact ROG Ally X VID/PID recognition.
- Add a 250 Hz native raw-state capture thread without application deadzones, curves, or smoothing.
- Add generated C/Dart FFI APIs and Flutter diagnostics for devices and observed input ranges.

## 0.2.0

- Add the opaque loopback session C ABI and generated Dart facade.
- Add native worker-thread state delivery with latest-state coalescing.
- Add sequence validation, disconnect release, and input-timeout watchdog.
- Add full-state fidelity and safety-release tests.

## 0.1.0

- Add Native Assets C++ smoke ABI and generated FFI bindings.
- Add controller state model, protocol layout, and backend interfaces.
