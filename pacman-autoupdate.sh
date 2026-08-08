#!/bin/bash
set -euo pipefail

LOG_FILE=/var/log/pacman-autoupdate.log
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Starting pacman system update: $(date -Is)"
pacman -Syu --noconfirm
echo "Finished pacman system update: $(date -Is)"
