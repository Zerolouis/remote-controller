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
