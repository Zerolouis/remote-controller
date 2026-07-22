# remote_controller_core

Native Windows controller core and generated Dart FFI facade for Remote Controller.

- Native sources: `native/`
- Native Assets hooks: `hook/`
- FFI generator: `tool/ffigen.dart`
- Generated bindings: `lib/src/third_party/`

The current exported ABI is a smoke-test surface. The opaque session API documented in `docs/PROJECT_KNOWLEDGE.md` will be added as the hardware and transport backends are implemented.
