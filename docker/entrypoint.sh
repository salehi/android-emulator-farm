#!/bin/bash
# Boots the farm AVD and exposes its adb port on 0.0.0.0:5556.
# The emulator itself only listens on 127.0.0.1:5555, so socat publishes it.
#
# Environment:
#   BOOT_TIMEOUT     seconds to wait for sys.boot_completed (default 600)
#   EMULATOR_MEMORY  guest RAM in MB (default: the AVD's 1536)
#   EMULATOR_CORES   guest CPU cores (default: the AVD's 2)
#   EMULATOR_GPU     -gpu mode (default swiftshader_indirect)
#   EMULATOR_ARGS    extra emulator flags, split on whitespace
set -euo pipefail

log() { echo "emulator-farm: $*"; }
die() { echo "emulator-farm: $*" >&2; exit 1; }

[[ -e /dev/kvm ]] || die "/dev/kvm is missing. Pass the device into the container."

export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-/opt/android-sdk}"
export PATH="$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/platform-tools:$PATH"

boot_timeout="${BOOT_TIMEOUT:-600}"
[[ "$boot_timeout" =~ ^[0-9]+$ ]] || die "BOOT_TIMEOUT must be a number of seconds"

args=(
	-avd farm
	-no-window
	-no-audio
	-no-boot-anim
	-no-snapshot
	-gpu "${EMULATOR_GPU:-swiftshader_indirect}"
	-accel on
	-port 5554
	-no-metrics
)
[[ -n "${EMULATOR_MEMORY:-}" ]] && args+=(-memory "$EMULATOR_MEMORY")
[[ -n "${EMULATOR_CORES:-}" ]] && args+=(-cores "$EMULATOR_CORES")
# shellcheck disable=SC2206 # word splitting is the documented behaviour
[[ -n "${EMULATOR_ARGS:-}" ]] && args+=(${EMULATOR_ARGS})

adb start-server >/dev/null

log "starting API ${EMULATOR_API} (boot timeout ${boot_timeout}s)"
emulator "${args[@]}" &
emu_pid=$!

# Publish adb for other containers and the host. 5556 stays free of the emulator.
socat TCP-LISTEN:5556,fork,reuseaddr,bind=0.0.0.0 TCP:127.0.0.1:5555 &
socat_pid=$!

shutdown() {
	log "stopping"
	adb -s emulator-5554 emu kill >/dev/null 2>&1 || kill "$emu_pid" 2>/dev/null || true
	kill "$socat_pid" 2>/dev/null || true
	wait "$emu_pid" 2>/dev/null || true
	exit 0
}
trap shutdown TERM INT

deadline=$((SECONDS + boot_timeout))
until adb -s emulator-5554 shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' | grep -q '^1$'; do
	kill -0 "$emu_pid" 2>/dev/null || die "emulator process exited before boot (API ${EMULATOR_API})"
	((SECONDS < deadline)) || die "boot timed out after ${boot_timeout}s (API ${EMULATOR_API})"
	sleep 2
done

log "boot completed (API ${EMULATOR_API}) in ${SECONDS}s"
# wait returns early when a trapped signal arrives, so the trap can run.
wait "$emu_pid"
