#!/bin/bash
set -euo pipefail

LOG_FILE="$HOME/.local/state/yay-autoupdate.log"
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Starting yay AUR update: $(date -Is)"
yay -Syu --noconfirm --removemake --cleanafter \
    --answerclean None --answerdiff None --answeredit None --answerupgrade All
echo "Finished yay AUR update: $(date -Is)"
