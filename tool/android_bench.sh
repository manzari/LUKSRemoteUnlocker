#!/usr/bin/env bash
# Runs inside the emulator image (make test-android-bench): boots the AVD, runs the bench test, answers system prompts.
set -euo pipefail

pkg=dev.manzari.luksremoteunlocker
out=/work/build/android-bench
mkdir -p "$out"
: >"$out/locks.log"

accel=on
boot_timeout=300
if [ "${EMULATOR_ACCEL:-kvm}" = off ]; then
  accel=off
  boot_timeout=2400
fi

emulator -avd bench -no-window -no-audio -no-boot-anim -no-snapshot -wipe-data -accel "$accel" \
  -gpu swiftshader_indirect -memory 3072 -cores 4 >"$out/emulator.log" 2>&1 &
emu=$!
helpers=()
cleanup() {
  for p in "${helpers[@]}"; do kill "$p" 2>/dev/null || true; done
  adb emu kill >/dev/null 2>&1 || true
  wait "$emu" 2>/dev/null || true
  adb kill-server >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Booting the emulator (accel $accel)..."
booting=$(date +%s)
timeout "$boot_timeout" adb wait-for-device
timeout "$boot_timeout" bash -c 'until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d "\r")" = 1 ]; do sleep 5; done'
echo "Booted in $(( $(date +%s) - booting )) s"
adb shell input keyevent KEYCODE_WAKEUP
adb shell wm dismiss-keyguard || true
for s in window_animation_scale transition_animation_scale animator_duration_scale; do
  adb shell settings put global "$s" 0
done

# Grants the notification permission once the test app is installed, so no dialog blocks the run.
(
  until adb shell pm list packages 2>/dev/null | grep -qx "package:$pkg"; do sleep 1; done
  adb shell pm grant "$pkg" android.permission.POST_NOTIFICATIONS
) &
helpers+=($!)

# Records foreground service, wake lock and Wi-Fi lock as the OS sees them.
(
  while sleep 2; do
    {
      adb shell dumpsys activity services "$pkg" 2>/dev/null | grep -E "ForegroundService|isForeground=|foregroundServiceType" | sed 's/^ */service: /'
      adb shell dumpsys power 2>/dev/null | grep -F "ForegroundService:WakeLock" | sed 's/^ */power: /'
      adb shell dumpsys wifi 2>/dev/null | grep -F "ForegroundService:WifiLock" | sed 's/^ */wifi: /'
    } | sed "s/^/$(date +%T) /" >>"$out/locks.log" || true
  done
) &
helpers+=($!)

# A sensor touch completes any biometric prompt; without a prompt it does nothing.
(while sleep 2; do adb emu finger touch 1 >/dev/null 2>&1 || true; done) &
helpers+=($!)

cd /work/app
flutter pub get >/dev/null
status=0
flutter test -d emulator-5554 \
  --dart-define=BENCH=1 \
  --dart-define=BENCH_PASSPHRASE="$BENCH_PASS" \
  --dart-define=BENCH_PREBOOT_KEYS="$BENCH_PREBOOT_KEYS" \
  --dart-define=BENCH_KEY="$(base64 -w0 /work/bench/fixtures/id_ed25519_bench)" \
  integration_test/bench_run_test.dart || status=$?

echo "OS view of the service and locks during the run (build/android-bench/locks.log):"
sort -u -k2 "$out/locks.log" | head -20
exit $status
