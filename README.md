# LUKS Remote Unlocker

Unlocks LUKS-encrypted Linux servers waiting at the Dropbear pre-boot prompt, from Android, Linux desktop or the command line.

## Make targets

Everything runs in Docker (`tool/Dockerfile.dart`, `tool/Dockerfile.flutter`, `tool/Dockerfile.emulator`); nothing is installed on the host.

| Target | What it does |
| --- | --- |
| `make test` | Analysis and tests for `unlock_core`, `unlock_cli` and the app |
| `make test-core` / `test-cli` / `test-app` | Same for one package; `ARGS="test/x_test.dart"` narrows the run |
| `make cli` | Builds `build/luks-unlock` |
| `make apk` | Debug Android APK |
| `make apk-release` | Signed release APK; needs `app/android/key.properties` |
| `make aab` | Signed release app bundle for the Play Store; needs `app/android/key.properties` |
| `make linux` | Debug Linux desktop build |
| `make shell-dart` / `shell-flutter` | Interactive shell in the toolchain container |
| `make run-dart CMD="..."` / `run-flutter CMD="..."` | One command in the toolchain container |
| `make bench-up` / `bench-down` | Start or remove the Dropbear test bench |
| `make test-bench` | Engine and CLI tests against the running bench |
| `make test-app-bench` | Linux app under Xvfb unlocks the three bench targets in parallel (resets them first) |
| `make test-android-bench` | Same flow on an Android emulator (`tool/Dockerfile.emulator`); needs a Docker daemon that sees `/dev/kvm`, `EMULATOR_ACCEL=off` runs without it, very slowly |
