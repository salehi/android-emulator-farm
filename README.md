# android-emulator-farm

Headless Android emulators for pre-release testing. One image per API from
24 through 36. Pull a prebuilt image, boot it, and install an APK or AAB
before that build goes to production.

Images are `linux/amd64`. The system images are `x86_64` and need `/dev/kvm`
on the host. The host needs `make`, `docker`, `docker-compose`, and
`/dev/kvm`. Nothing Android-related is installed on the host.

Run every command from this directory.

## Pieces

| Path | Role |
|---|---|
| `docker/Dockerfile` | Stage `sdk` is shared. Stage `emulator` is one API. |
| `docker-compose.yml` | One service per API. Shared settings live in YAML anchors. |
| `docker/entrypoint.sh` | Boots the AVD headless and publishes adb on port 5556. |
| `Makefile` | `image`, `pull`, `run`, `up`, `farm`, `ps`, `down`. |
| `.github/workflows/publish.yml` | Builds every API and pushes it to Docker Hub. |

## Prebuilt images

Docker Hub repository: `<namespace>/android-emulator-farm`.

`make run` pulls one tag and starts it. `IMAGE` is the repository name,
without a tag.

```sh
make run API=36 IMAGE=<namespace>/android-emulator-farm
make run-farm IMAGE=<namespace>/android-emulator-farm
make down API=36
```

Each emulator needs about 2 GB of RAM. Starting all 13 needs on the order of
26 GB, plus `/dev/kvm`.

Host adb is `127.0.0.1` and port `5000+API`. Compose binds that port to
localhost only.

| API | Android | System image | Tags | Host adb |
|---|---|---|---|---|
| 24 | 7.0 | google_apis | `api24`, `24`, `android-7.0`, `api24-google_apis` | `127.0.0.1:5024` |
| 25 | 7.1 | google_apis | `api25`, `25`, `android-7.1`, `api25-google_apis` | `127.0.0.1:5025` |
| 26 | 8.0 | google_apis | `api26`, `26`, `android-8.0`, `api26-google_apis` | `127.0.0.1:5026` |
| 27 | 8.1 | default | `api27`, `27`, `android-8.1`, `api27-default` | `127.0.0.1:5027` |
| 28 | 9 | google_apis | `api28`, `28`, `android-9`, `api28-google_apis` | `127.0.0.1:5028` |
| 29 | 10 | google_apis | `api29`, `29`, `android-10`, `api29-google_apis` | `127.0.0.1:5029` |
| 30 | 11 | google_apis | `api30`, `30`, `android-11`, `api30-google_apis` | `127.0.0.1:5030` |
| 31 | 12 | google_apis | `api31`, `31`, `android-12`, `api31-google_apis` | `127.0.0.1:5031` |
| 32 | 12.1 | google_apis | `api32`, `32`, `android-12.1`, `api32-google_apis` | `127.0.0.1:5032` |
| 33 | 13 | google_apis | `api33`, `33`, `android-13`, `api33-google_apis` | `127.0.0.1:5033` |
| 34 | 14 | google_apis | `api34`, `34`, `android-14`, `api34-google_apis` | `127.0.0.1:5034` |
| 35 | 15 | google_apis | `api35`, `35`, `android-15`, `api35-google_apis` | `127.0.0.1:5035` |
| 36 | 16 | google_apis | `api36`, `36`, `android-16`, `api36-google_apis`, `latest` | `127.0.0.1:5036` |

Every publish also pushes `api<API>-<git sha>`. That tag does not move.
`latest` is API 36. `:sdk` is the shared command-line tools layer used while
publishing. It is not an emulator.

API 27 uses the `default` system image. Google does not publish a
`google_apis` `x86_64` image for that level. API 37 packages are named
`android-37.0` and are not in this set.

## Install a build

Wait until the container logs `boot completed`, then point `adb` at the
published port.

```sh
adb connect 127.0.0.1:5036
adb -s 127.0.0.1:5036 install -r app.apk
adb -s 127.0.0.1:5036 shell am instrument -w your.test/androidx.test.runner.AndroidJUnitRunner
```

For an AAB, build an APK set with `bundletool` and install that set:

```sh
bundletool build-apks --bundle=app.aab --output=app.apks --connected-device
bundletool install-apks --apks=app.apks --device-id=127.0.0.1:5036
```

## Build locally

Build one API at a time. The first build downloads Debian 13, the command-line
tools, platform-tools, and the emulator into the `sdk` stage. Each later API
reuses that stage and downloads only its own system image and platform package.

`make image` refuses to run without `API`, so a bare `make image` cannot
start every system-image download at once.

```sh
make image API=36
make up API=36
make ps
make down API=36
make down
```

Skip an API whose image already exists (`docker images android-emulator-farm`).
Changing an earlier `RUN` in the Dockerfile makes the next build download
that stage again.

Builds set `BUILDX_BUILDER=default`. The `meshcheck` builder cannot resolve
`deb.debian.org`.

## Publish to Docker Hub

The workflow `.github/workflows/publish.yml` builds `linux/amd64` images and
pushes the tags above. It runs on a push to `main` that changes the image
or the workflow, and from the Actions tab (`workflow_dispatch`) for one API
or all of them.

Create a public Docker Hub repository named `android-emulator-farm`. Create
an access token with Read and Write scope. From a checkout whose `origin`
is this GitHub repo, set the account name and the token:

```sh
gh variable set DOCKERHUB_USERNAME --body "your-dockerhub-username"
gh secret set DOCKERHUB_TOKEN
```

`gh secret set` reads the token from stdin and does not print it. The
username is the Docker Hub account name. A `DOCKERHUB_USERNAME` secret is
accepted when the variable is unset.

A full publish builds the SDK layer once, then up to three API images at a
time. Each system image is large. Publishing all 13 takes a long time and a
lot of Actions minutes.
