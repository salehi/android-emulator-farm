# android-emulator-farm

[![Publish images](https://github.com/salehi/android-emulator-farm/actions/workflows/publish.yml/badge.svg)](https://github.com/salehi/android-emulator-farm/actions/workflows/publish.yml)
[![CI](https://github.com/salehi/android-emulator-farm/actions/workflows/ci.yml/badge.svg)](https://github.com/salehi/android-emulator-farm/actions/workflows/ci.yml)
[![Docker Hub](https://img.shields.io/docker/pulls/s4l3h1/android-emulator-farm)](https://hub.docker.com/r/s4l3h1/android-emulator-farm)

Ready-to-run Android emulators in Docker, one image per Android API level,
built and published by GitHub Actions.

## What this project is for

An Android release has to work on every Android version it supports, not
just the one on the developer's phone. This project gives you a headless
emulator for each API level from 24 (Android 7.0) to 36 (Android 16) as a
Docker image. Pull the version you need, install an APK or AAB over adb, and
run your checks before that build reaches production.

- **No Android SDK on the host.** You need Docker and `/dev/kvm`.
- **One tag per API.** Test the same build against several Android versions
  side by side.
- **Built in CI.** GitHub Actions builds and publishes every image. An
  optional smoke test boots each image on a KVM runner and checks adb before
  it is pushed.
- **One list to maintain.** `emulators.json` decides what is built, how it is
  tagged, and what the docs say.

## Quick start

```sh
docker run -d --name android-36 \
  --device /dev/kvm --shm-size 2g \
  -p 127.0.0.1:5036:5556 \
  s4l3h1/android-emulator-farm:api36

docker logs -f android-36          # wait for "boot completed"

adb connect 127.0.0.1:5036
adb -s 127.0.0.1:5036 install -r app.apk
adb -s 127.0.0.1:5036 shell am instrument -w your.test/androidx.test.runner.AndroidJUnitRunner
```

For an AAB, build an APK set with `bundletool` and install it:

```sh
bundletool build-apks --bundle=app.aab --output=app.apks --connected-device
bundletool install-apks --apks=app.apks --device-id=127.0.0.1:5036
```

The container reports `healthy` once Android has finished booting. Each
emulator needs about 2 GB of RAM.

## Images and tags

Docker Hub: [`s4l3h1/android-emulator-farm`](https://hub.docker.com/r/s4l3h1/android-emulator-farm).
Images are `linux/amd64` with `x86_64` system images. Every build also pushes
`api<API>-<git sha>`, which never moves. Compose binds each emulator's adb to
`127.0.0.1:5000+API`.

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

API 27 uses the `default` system image because Google does not publish a
`google_apis` `x86_64` image for that level.

## Running several versions with Compose

`docker-compose.yml` has one service per API and runs the prebuilt images
from Docker Hub. A missing image is pulled on first start. Use it directly or
through the Makefile:

```sh
docker compose up -d api34      # or: make up API=34
make farm                       # start all
make ps                         # status and health
make logs API=34
make pull API=34                # refresh to the newest published image
make down API=34                # stop one
make down                       # stop all
```

Set `IMAGE` to run images from another namespace, for example
`IMAGE=myname/android-emulator-farm make up API=34`.

Starting all of them needs on the order of 26 GB of RAM.

### Runtime settings

| Variable | Default | Meaning |
|---|---|---|
| `BOOT_TIMEOUT` | `600` | Seconds to wait for Android to finish booting. |
| `EMULATOR_MEMORY` | `1536` | Guest RAM in MB. |
| `EMULATOR_CORES` | `2` | Guest CPU cores. |
| `EMULATOR_GPU` | `swiftshader_indirect` | Emulator `-gpu` mode. |
| `EMULATOR_ARGS` | | Extra emulator flags, split on whitespace. |

## How the images are built

All building, testing, and publishing happens in GitHub Actions.

```
emulators.json ──► plan ──► sdk layer ──► API 24 … API 36 ──► Docker Hub description
                  (matrix)  (pushed once)  build → [smoke test] → push
```

1. **plan** validates `emulators.json` and turns it into a build matrix with
   every tag (`.github/scripts/matrix.sh`).
2. **sdk** builds the shared layer (Debian 13, JDK 21, command-line tools,
   platform-tools, emulator) once and pushes it as `:sdk-<sha>`.
3. **API jobs** reuse that layer, add one system image each, and push it.
   With the optional smoke test, each image is first booted on a KVM runner
   and checked over adb through the published port
   (`.github/scripts/smoke-test.sh`), and only images that pass are pushed.
4. **description** updates the Docker Hub overview from `docs/dockerhub.md`
   and the short description from `emulators.json`.

The publish workflow runs on a push to `main` that touches `docker/`,
`emulators.json`, or the publish scripts. Run it by hand from the Actions tab
to publish `all` or a list such as `34 35 36`, with or without the smoke
test:

```sh
gh workflow run publish.yml -f apis="34 35 36"
gh workflow run publish.yml -f apis=all -f smoke_test=true
```

The smoke test is off for pushes to `main` and off by default for manual
runs. Turn it on after changing `docker/` or adding an API.

The CI workflow lints the scripts, Dockerfile, and workflows, and checks that
generated files match `emulators.json`.

## Repository layout

| Path | Role |
|---|---|
| `emulators.json` | The list of APIs, their system images, `latest`, the Docker Hub namespace and repository, and the short description. |
| `docker/Dockerfile` | Stage `sdk` is shared. Stage `emulator` adds one API. |
| `docker/entrypoint.sh` | Boots the AVD headless and publishes adb on port 5556. |
| `docker/healthcheck.sh` | Healthy once `sys.boot_completed` is 1. |
| `docker-compose.yml` | Generated. One service per API, using the Docker Hub images. |
| `docs/dockerhub.md` | Docker Hub overview. Its tag table is generated. |
| `scripts/validate.sh` | Validates `emulators.json`. |
| `scripts/render.sh` | Regenerates `docker-compose.yml` and the tag tables. |
| `.github/scripts/` | CI-only: matrix planning and the smoke test. |
| `.github/workflows/publish.yml` | Builds, optionally smoke-tests, and pushes images. |
| `.github/workflows/dockerhub-description.yml` | Syncs the Docker Hub description. |
| `.github/workflows/ci.yml` | Lint and generated-file checks. |

## Adding or changing an API

1. Edit `emulators.json`: add an entry with `api`, `android`, and
   `system_image`, or move `latest`.
2. Run `make render` (needs `jq`) to regenerate `docker-compose.yml` and the
   tag tables, then `make check`.
3. Commit and push to `main`. The publish workflow builds and pushes the
   change, and the description workflow updates Docker Hub.
