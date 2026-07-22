# Contributing

Remote Controller is in an architecture-first MVP phase. Please open an issue before adding a new input, transport, isolation, or virtual-controller backend.

## Development prerequisites

- Windows 11
- Flutter stable with Windows desktop enabled
- Visual Studio with Desktop development with C++
- Windows 10/11 SDK
- LLVM/libclang when regenerating FFI bindings (`LIBCLANG_PATH` may point to `libclang.dll`)

## Local checks

From `packages/remote_controller_core`, regenerate bindings with `dart run tool/ffigen.dart`, then run `dart analyze` and `flutter test`. From `apps/remote_controller`, run `flutter analyze`, `flutter test`, and `flutter build windows`.

On localized Windows installations, `native_toolchain_c 0.19.2` may fail to auto-detect Visual Studio from a plain `dart test`. Using `flutter test` supplies the compiler configuration explicitly and is the supported validation path until the upstream encoding issue is resolved.

All source files must retain their SPDX license identifier. Imported code must include its original copyright and a matching entry in `third_party/NOTICE.md`.
