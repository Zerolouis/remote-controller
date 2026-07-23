# remote_controller_core

Native Windows controller core and generated Dart FFI facade for Remote Controller.

- Native sources: `native/`
- Native Assets hooks: `hook/`
- FFI generator: `tool/ffigen.dart`
- Generated bindings: `lib/src/third_party/`

The exported ABI now includes an opaque loopback session used to validate the
shared state machine, full-state fidelity, sequence rejection, disconnect
release, and input-timeout watchdog. SDL, LAN, HidHide, and ViGEm backends are
not connected yet.
