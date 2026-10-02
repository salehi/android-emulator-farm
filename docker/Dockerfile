# syntax=docker/dockerfile:1
# Headless Android emulator images, one per API level.
#
# Stage sdk is shared. It holds the downloads that do not change with the API
# number: Debian packages, command-line tools, platform-tools, and the
# emulator. Stage emulator adds one system image and one platform.
#
# A local build runs both stages. CI builds sdk once, pushes it, and then
# overrides that stage (--build-context sdk=docker-image://...) so each API
# downloads only its own system image.
#
# The host only needs Docker and /dev/kvm. Build arg API is 24 through 36.
# Images are linux/amd64. The system images are x86_64 and use KVM.

# Base is Debian 13 (trixie). Bookworm's regular security support ended in
# July 2026.

# --- sdk: built once, reused by every API target ---------------------------
FROM debian:trixie AS sdk

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        openjdk-21-jdk-headless \
        unzip curl ca-certificates socat \
        libnss3 libx11-6 libxcomposite1 libxcursor1 libxi6 libxtst6 \
        libxdamage1 libxrandr2 libxext6 libxfixes3 libxcb1 libglib2.0-0t64 \
        libpulse0 libasound2t64 libglu1-mesa libdrm2 libxkbfile1 \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    ANDROID_HOME=/opt/android-sdk
ENV PATH=$PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator

# cmdline-tools, platform-tools, and the emulator are one layer.
# 15859902 runs on JDK 21. Splitting this instruction downloads the archives again.
ARG CMDLINE_TOOLS_VERSION=15859902
RUN mkdir -p $ANDROID_SDK_ROOT/cmdline-tools \
    && curl -fsSL -o /tmp/cmdline-tools.zip \
        https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip \
    && unzip -q /tmp/cmdline-tools.zip -d $ANDROID_SDK_ROOT/cmdline-tools \
    && mv $ANDROID_SDK_ROOT/cmdline-tools/cmdline-tools $ANDROID_SDK_ROOT/cmdline-tools/latest \
    && rm /tmp/cmdline-tools.zip \
    && { yes | sdkmanager --licenses >/dev/null || true; } \
    && sdkmanager --install "platform-tools" "emulator"

# --- emulator: one API. Inherits the sdk stage from the build cache. -------
FROM sdk AS emulator

# Declared only in this stage. Changing API or SYSTEM_IMAGE does not rebuild
# sdk, and does not re-download cmdline-tools, platform-tools, or the emulator.
ARG API=36
ARG SYSTEM_IMAGE=google_apis
ARG REVISION=local
ENV EMULATOR_API=${API}

LABEL org.opencontainers.image.title="android-emulator-farm" \
      org.opencontainers.image.description="Headless Android ${API} emulator (${SYSTEM_IMAGE}, x86_64)" \
      org.opencontainers.image.revision="${REVISION}"

# One package, one layer. A failure in a later step must not discard this zip.
RUN sdkmanager --install "system-images;android-${API};${SYSTEM_IMAGE};x86_64"

# Platform is a separate, smaller download.
RUN sdkmanager --install "platforms;android-${API}"

# Local only. No network.
RUN echo no | avdmanager create avd --force --name farm \
        --package "system-images;android-${API};${SYSTEM_IMAGE};x86_64" \
    && sed -i \
        -e 's/^hw.ramSize=.*/hw.ramSize=1536/' \
        -e 's/^hw.cpu.ncore=.*/hw.cpu.ncore=2/' \
        /root/.android/avd/farm.avd/config.ini \
    && { grep -q '^hw.keyboard=' /root/.android/avd/farm.avd/config.ini \
        || echo 'hw.keyboard=yes' >> /root/.android/avd/farm.avd/config.ini; } \
    && printf '%s\n' "system-images;android-${API};${SYSTEM_IMAGE};x86_64" \
        > /opt/android-sdk/system-image-package

COPY entrypoint.sh healthcheck.sh /
RUN chmod +x /entrypoint.sh /healthcheck.sh

# Healthy once Android has finished booting. Newer APIs take a few minutes.
HEALTHCHECK --interval=15s --timeout=10s --start-period=10m --retries=3 \
    CMD ["/healthcheck.sh"]

EXPOSE 5556
ENTRYPOINT ["/entrypoint.sh"]
