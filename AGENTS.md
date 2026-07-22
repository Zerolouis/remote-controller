# Repository guidance

- The project is GPL-3.0-only. Preserve SPDX identifiers and upstream notices.
- Keep Flutter UI, ViewModels, repositories, and services separated.
- Do not put real-time input, networking, isolation, or virtual-controller work on the Flutter UI thread.
- Generate Dart FFI bindings with `packages/remote_controller_core/tool/ffigen.dart`; do not handwrite bindings.
- Build native code through Native Assets hooks, not ad-hoc compiler commands.
- Update `docs/PROJECT_KNOWLEDGE.md` whenever architecture, protocol, dependencies, licensing, or critical implementation changes.
- Do not vendor complete Sunshine or Moonlight trees. Import only reviewed controller-path code when a concrete implementation needs it.
