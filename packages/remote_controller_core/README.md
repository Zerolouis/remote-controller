# remote_controller_core

Native Windows controller core and generated Dart FFI facade for Remote Controller.

- Native sources: `native/`
- Native Assets hooks: `hook/`
- FFI generator: `tool/ffigen.dart`
- Generated bindings: `lib/src/third_party/`

The exported ABI includes SDL input capture, ViGEm X360 output, a verified
ViGEmBus installer launcher, local loopback/bridge diagnostics, and trusted-LAN
Client/Server sessions. Real-time sampling, TCP/UDP transport, watchdog release,
ViGEm submission, and rumble feedback remain in native worker threads.

The project intentionally does not hide the physical controller on the Client.
The current network protocol is not encrypted and is limited to trusted LANs.
