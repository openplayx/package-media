# Linux build and test environment for package-media (and package-ffmpeg):
# the CI Linux image's packages (build/scripts/app/linux/Dockerfile) plus
# meson and the desktop libraries libmpv links dynamically (ffmpeg only probes
# the format test samples). Flutter is mounted
# or cloned at run time (see tool/linux/run.sh).
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git unzip xz-utils zip build-essential clang cmake ninja-build \
    pkg-config autoconf automake libtool nasm python3 python3-pip meson patchelf file \
    libgtk-3-dev libxcb-composite0-dev libxcb-xv0-dev libxcb-randr0-dev libxcb-keysyms1-dev \
    libsecret-1-dev xvfb xauth dbus-x11 mesa-utils libgl1-mesa-dri fonts-dejavu-core \
    libfontconfig-dev libegl-dev libgles-dev libepoxy-dev libpulse-dev libasound2-dev \
    libcurl4-openssl-dev libc++-dev libc++abi-dev ffmpeg \
    && rm -rf /var/lib/apt/lists/*
