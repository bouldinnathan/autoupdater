#!/bin/bash
set -euo pipefail

LOG_FILE=/var/log/system-update.log
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Starting system update: $(date -Is)"

if command -v pacman >/dev/null 2>&1; then
    pacman -Syu --noconfirm
elif command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get -y -o Dpkg::Options::="--force-confold" full-upgrade
    apt-get -y autoremove
elif command -v dnf >/dev/null 2>&1; then
    dnf -y upgrade --refresh
elif command -v zypper >/dev/null 2>&1; then
    zypper --non-interactive refresh
    zypper --non-interactive update
elif command -v apk >/dev/null 2>&1; then
    apk update
    apk upgrade
else
    echo "No supported package manager found (looked for pacman, apt-get, dnf, zypper, apk)." >&2
    exit 1
fi

echo "Finished system update: $(date -Is)"
