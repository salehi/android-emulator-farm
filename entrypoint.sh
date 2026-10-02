#!/bin/bash
# Boots the farm AVD and exposes its adb port on 0.0.0.0:5556.
# The emulator itself only listens on 127.0.0.1:5555, so socat publishes it.
set -euo pipefail

if [[ ! -e /dev/kvm ]]; then
	echo "emulator-farm: /dev/kvm is missing. Pass the device into the container." >&2
	exit 1
fi

export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-/opt/android-sdk}"
export PATH="$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/platform-tools:$PATH"

adb start-server >/dev/null

emulator -avd farm \
	-no-window \
	-no-audio \
	-no-boot-anim \
	-no-snapshot \
	-gpu swiftshader_indirect \
	-accel on \
	-port 5554 \
	-no-metrics &
emu_pid=$!

# Publish adb for other containers and the host. 5556 stays free of the emulator.
socat TCP-LISTEN:5556,fork,reuseaddr,bind=0.0.0.0 TCP:127.0.0.1:5555 &

adb wait-for-device
booted=0
for _ in $(seq 1 120); do
	if adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' | grep -q '^1$'; then
		booted=1
		break
	fi
	if ! kill -0 "$emu_pid" 2>/dev/null; then
		echo "emulator-farm: emulator process exited before boot (API ${EMULATOR_API})" >&2
		exit 1
	fi
	sleep 2
done

if [[ "$booted" -ne 1 ]]; then
	echo "emulator-farm: boot timed out (API ${EMULATOR_API})" >&2
	exit 1
fi

echo "emulator-farm: boot completed (API ${EMULATOR_API})"
wait "$emu_pid"
