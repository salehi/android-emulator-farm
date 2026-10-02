# android-emulator-farm

Headless Android emulators in Docker, one image per API level. Use them to
install and test an APK or AAB on real Android system images before a build
goes to production, on a laptop or a CI runner, without installing the
Android SDK on the host.

- One tag per Android API, from 24 (Android 7.0) to 36 (Android 16).
- `x86_64` system images with KVM acceleration. Images are `linux/amd64`.
- adb is published on container port `5556`.
- The container reports `healthy` once Android has finished booting.

Source, issues, and build workflow: https://github.com/salehi/android-emulator-farm

## Quick start

The host needs Docker and `/dev/kvm`.

```sh
docker run -d --name android-36 \
  --device /dev/kvm --shm-size 2g \
  -p 127.0.0.1:5036:5556 \
  s4l3h1/android-emulator-farm:api36

# Wait for "boot completed" (or for the container to become healthy).
docker logs -f android-36

adb connect 127.0.0.1:5036
adb -s 127.0.0.1:5036 install -r app.apk
```

For an AAB, build an APK set with `bundletool` and install it:

```sh
bundletool build-apks --bundle=app.aab --output=app.apks --connected-device
bundletool install-apks --apks=app.apks --device-id=127.0.0.1:5036
```

## Compose

```yaml
services:
  android-34:
    image: s4l3h1/android-emulator-farm:api34
    devices:
      - /dev/kvm:/dev/kvm
    shm_size: "2gb"
    ports:
      - "127.0.0.1:5034:5556"
```

The source repository has a ready-made `docker-compose.yml` with one service
per API.

## Tags

`api<API>-<git sha>` is also pushed for every build and never moves. `latest`
follows the newest API. The suggested host port is `5000+API`.

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

## Configuration

| Variable | Default | Meaning |
|---|---|---|
| `BOOT_TIMEOUT` | `600` | Seconds to wait for Android to finish booting. |
| `EMULATOR_MEMORY` | `1536` | Guest RAM in MB. |
| `EMULATOR_CORES` | `2` | Guest CPU cores. |
| `EMULATOR_GPU` | `swiftshader_indirect` | Emulator `-gpu` mode. |
| `EMULATOR_ARGS` | | Extra emulator flags, split on whitespace. |

Each emulator needs about 2 GB of host RAM.
