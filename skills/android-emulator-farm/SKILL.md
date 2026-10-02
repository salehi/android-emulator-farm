---
name: android-emulator-farm
description: Run headless Android emulators (API 24-36) in Docker from s4l3h1/android-emulator-farm and drive them over adb. Use when a project needs to install or test an APK/AAB on one or more Android versions, run instrumentation tests across an API matrix, or work out which emulator is listening on which adb port (host port 5000+API, e.g. 127.0.0.1:5034 is Android 14).
---

# Android emulator farm

Prebuilt headless Android emulators, one Docker image per API level, from
[`s4l3h1/android-emulator-farm`](https://hub.docker.com/r/s4l3h1/android-emulator-farm)
([source](https://github.com/salehi/android-emulator-farm)). No Android SDK
is needed on the host for the emulator itself, only Docker and `/dev/kvm`.
The host does need `adb` (Android platform-tools) to talk to it.

## The port rule

**Host adb port = 5000 + API level.** The last two digits of the port are the
API level, so the port alone tells you which Android version you are talking
to:

```
127.0.0.1:50<API>  ->  container port 5556  ->  emulator adb (API <API>)
```

- adb serial on the host is `127.0.0.1:<5000+API>`, e.g. `127.0.0.1:5034`.
- Inside every container adb is published on port **5556** (socat to the
  emulator's own 5555). Always map host `5000+API` to container `5556`.
- Ports are bound to `127.0.0.1` only. Bind to another address only if the
  user asks for remote access.
- Inside the container the emulator is `emulator-5554`; that serial is not
  visible from the host. Use `127.0.0.1:<port>` from the host.
- Containers on the same Docker network reach it at `<container>:5556`,
  e.g. `adb connect emulator-farm-34:5556`.

## Port and version matrix

<!-- emulators:start -->
| API | Android | System image | Tags | Host adb |
|---|---|---|---|---|
| 24 | 7.0 | `google_apis` | `api24`, `24`, `android-7.0`, `api24-google_apis` | `127.0.0.1:5024` |
| 25 | 7.1 | `google_apis` | `api25`, `25`, `android-7.1`, `api25-google_apis` | `127.0.0.1:5025` |
| 26 | 8.0 | `google_apis` | `api26`, `26`, `android-8.0`, `api26-google_apis` | `127.0.0.1:5026` |
| 27 | 8.1 | `default` | `api27`, `27`, `android-8.1`, `api27-default` | `127.0.0.1:5027` |
| 28 | 9 | `google_apis` | `api28`, `28`, `android-9`, `api28-google_apis` | `127.0.0.1:5028` |
| 29 | 10 | `google_apis` | `api29`, `29`, `android-10`, `api29-google_apis` | `127.0.0.1:5029` |
| 30 | 11 | `google_apis` | `api30`, `30`, `android-11`, `api30-google_apis` | `127.0.0.1:5030` |
| 31 | 12 | `google_apis` | `api31`, `31`, `android-12`, `api31-google_apis` | `127.0.0.1:5031` |
| 32 | 12.1 | `google_apis` | `api32`, `32`, `android-12.1`, `api32-google_apis` | `127.0.0.1:5032` |
| 33 | 13 | `google_apis` | `api33`, `33`, `android-13`, `api33-google_apis` | `127.0.0.1:5033` |
| 34 | 14 | `google_apis` | `api34`, `34`, `android-14`, `api34-google_apis` | `127.0.0.1:5034` |
| 35 | 15 | `google_apis` | `api35`, `35`, `android-15`, `api35-google_apis` | `127.0.0.1:5035` |
| 36 | 16 | `google_apis` | `api36`, `36`, `android-16`, `api36-google_apis`, `latest` | `127.0.0.1:5036` |
<!-- emulators:end -->

All images are `linux/amd64` with `x86_64` system images. API 27 uses
`default` because Google publishes no `google_apis` `x86_64` image for it.
Each build also pushes an immutable `api<API>-<git sha>` tag; pin to it for
reproducible CI.

Naming convention used everywhere: image tag `api<API>`, Compose service
`api<API>`, container `emulator-farm-<API>`, host port `5000+API`.

## Start one emulator

```sh
API=34
docker run -d --name emulator-farm-$API \
  --device /dev/kvm --shm-size 2g \
  -p 127.0.0.1:$((5000 + API)):5556 \
  s4l3h1/android-emulator-farm:api$API
```

`--device /dev/kvm` and `--shm-size 2g` are required. Each emulator needs
about 2 GB of host RAM; the full farm needs about 26 GB.

## Wait for boot

The container is `healthy` once `sys.boot_completed` is 1, and logs
`boot completed (API <API>)`. Wait on the health status, not on a sleep:

```sh
until [ "$(docker inspect -f '{{.State.Health.Status}}' emulator-farm-$API)" = healthy ]; do
  [ "$(docker inspect -f '{{.State.Running}}' emulator-farm-$API)" = true ] \
    || { docker logs emulator-farm-$API; exit 1; }
  sleep 5
done
adb connect 127.0.0.1:$((5000 + API))
adb -s 127.0.0.1:$((5000 + API)) wait-for-device
```

Boot usually takes 1-3 minutes; the container gives up after `BOOT_TIMEOUT`
(600 s) and exits.

## Use it over adb

Always pass `-s 127.0.0.1:<port>` when more than one emulator is connected.

```sh
S=127.0.0.1:5034                                    # Android 14
adb connect $S
adb -s $S install -r app.apk
adb -s $S shell am instrument -w com.example.test/androidx.test.runner.AndroidJUnitRunner
adb -s $S shell getprop ro.build.version.sdk        # prints 34, confirms the port
adb -s $S logcat -d > logcat-api34.txt
adb -s $S exec-out screencap -p > screen-api34.png
```

AAB: build an APK set for the connected device, then install it.

```sh
bundletool build-apks --bundle=app.aab --output=app.apks --connected-device --device-id=$S
bundletool install-apks --apks=app.apks --device-id=$S
```

Gradle connected tests target one device through `ANDROID_SERIAL`:

```sh
ANDROID_SERIAL=127.0.0.1:5034 ./gradlew connectedDebugAndroidTest
```

## Test across a version matrix

Map the port back to the version from the port itself (`port - 5000 = API`):

```sh
APIS="26 30 34 36"
for api in $APIS; do
  docker run -d --name emulator-farm-$api --device /dev/kvm --shm-size 2g \
    -p 127.0.0.1:$((5000 + api)):5556 s4l3h1/android-emulator-farm:api$api
done
for api in $APIS; do
  until [ "$(docker inspect -f '{{.State.Health.Status}}' emulator-farm-$api)" = healthy ]; do sleep 5; done
  s=127.0.0.1:$((5000 + api))
  adb connect $s
  adb -s $s install -r app.apk
  adb -s $s shell am instrument -w com.example.test/androidx.test.runner.AndroidJUnitRunner \
    | tee "instrument-api$api.txt"
done
for api in $APIS; do docker rm -f emulator-farm-$api; done
```

Check RAM before starting many at once (about 2 GB each).

## Compose in another project

Copy only the services you need. Keep the port rule.

```yaml
x-emulator: &emulator
  devices: ["/dev/kvm:/dev/kvm"]
  shm_size: "2gb"
  environment:
    BOOT_TIMEOUT: "600"

services:
  api30:   # Android 11 -> adb 127.0.0.1:5030
    <<: *emulator
    image: s4l3h1/android-emulator-farm:api30
    container_name: emulator-farm-30
    ports: ["127.0.0.1:5030:5556"]
  api34:   # Android 14 -> adb 127.0.0.1:5034
    <<: *emulator
    image: s4l3h1/android-emulator-farm:api34
    container_name: emulator-farm-34
    ports: ["127.0.0.1:5034:5556"]
```

```sh
docker compose up -d api34
docker compose ps        # wait for (healthy)
```

A test-runner container on the same Compose network needs no published port:
`adb connect emulator-farm-34:5556`.

## GitHub Actions

Hosted `ubuntu-latest` runners have KVM, but it must be opened up first:

```yaml
- name: Enable KVM
  run: |
    echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' \
      | sudo tee /etc/udev/rules.d/99-kvm4all.rules
    sudo udevadm control --reload-rules
    sudo udevadm trigger --name-match=kvm
- name: Start Android 14
  run: |
    docker run -d --name emulator-farm-34 --device /dev/kvm --shm-size 2g \
      -p 127.0.0.1:5034:5556 s4l3h1/android-emulator-farm:api34
    until [ "$(docker inspect -f '{{.State.Health.Status}}' emulator-farm-34)" = healthy ]; do sleep 5; done
    adb connect 127.0.0.1:5034
```

A standard runner (16 GB) fits a few emulators at a time, not the whole farm.

## Runtime settings

| Variable | Default | Meaning |
|---|---|---|
| `BOOT_TIMEOUT` | `600` | Seconds to wait for boot before the container exits. |
| `EMULATOR_MEMORY` | `1536` | Guest RAM in MB. |
| `EMULATOR_CORES` | `2` | Guest CPU cores. |
| `EMULATOR_GPU` | `swiftshader_indirect` | Emulator `-gpu` mode. |
| `EMULATOR_ARGS` | | Extra emulator flags, split on whitespace. |

## Troubleshooting

- `/dev/kvm is missing`: the host has no KVM or it was not passed with
  `--device /dev/kvm`. Emulators will not run without it.
- `adb connect` says `failed to connect` or the device is `offline`: the
  emulator has not finished booting. Wait for `healthy`, then
  `adb disconnect <serial>` and connect again.
- Port already in use: another emulator for the same API is running. Check
  `docker ps --filter name=emulator-farm-`. Do not move it to another port;
  that breaks the port-to-version rule.
- Wrong version suspected: `adb -s <serial> shell getprop ro.build.version.sdk`
  must equal `port - 5000`.
- Container exits with `boot timed out`: raise `BOOT_TIMEOUT`, or lower load
  by running fewer emulators at once.
