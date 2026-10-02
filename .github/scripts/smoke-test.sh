#!/bin/bash
# Boots an emulator image and checks it the way a user would: the container
# becomes healthy, and adb works through the published port 5556.
#
#   .github/scripts/smoke-test.sh IMAGE:TAG API [TIMEOUT_SECONDS]
#
# Runs in the publish workflow on a KVM-enabled GitHub runner.
set -euo pipefail

image="${1:?usage: smoke-test.sh IMAGE:TAG API [TIMEOUT_SECONDS]}"
api="${2:?usage: smoke-test.sh IMAGE:TAG API [TIMEOUT_SECONDS]}"
timeout="${3:-900}"
name="smoke-api${api}-$$"

cleanup() {
	local status=$?
	if ((status != 0)); then
		echo "--- container log (last 80 lines) ---"
		docker logs --tail 80 "$name" 2>&1 || true
	fi
	docker rm -f "$name" >/dev/null 2>&1 || true
	exit "$status"
}
trap cleanup EXIT

echo "smoke-test: starting $image"
docker run -d --name "$name" \
	--device /dev/kvm --shm-size 2g \
	-e BOOT_TIMEOUT="$timeout" \
	"$image" >/dev/null

start=$SECONDS
while :; do
	state="$(docker inspect -f '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}}' "$name")"
	case "$state" in
		"running healthy") break ;;
		running*) ;;
		*) echo "smoke-test: container is $state" >&2; exit 1 ;;
	esac
	if ((SECONDS - start > timeout)); then
		echo "smoke-test: not healthy after ${timeout}s" >&2
		exit 1
	fi
	sleep 5
done
echo "smoke-test: healthy after $((SECONDS - start))s"

# Go through socat on 5556, the same path a published host port uses, while
# the entrypoint's own adb server stays attached to the emulator.
docker exec "$name" adb connect 127.0.0.1:5556
sdk="$(docker exec "$name" adb -s 127.0.0.1:5556 shell getprop ro.build.version.sdk | tr -d '\r')"
if [[ "$sdk" != "$api" ]]; then
	echo "smoke-test: expected SDK $api over port 5556, got '$sdk'" >&2
	exit 1
fi
docker exec "$name" adb -s 127.0.0.1:5556 shell pm list packages >/dev/null
echo "smoke-test: API $api answers over adb on port 5556"
