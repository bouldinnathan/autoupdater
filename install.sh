#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${USER:-$(whoami)}"

echo "== Checking for systemd =="
if ! command -v systemctl >/dev/null 2>&1 || [ ! -d /run/systemd/system ]; then
    echo "This system does not appear to be running systemd as its init system." >&2
    echo "This installer only supports systemd-based distros (Debian/Ubuntu, Fedora/RHEL/Rocky/Alma, openSUSE, Arch/Manjaro, systemd-enabled Alpine). Aborting." >&2
    exit 1
fi

echo "== Detecting package manager =="
PKG_MANAGER=""
for pm in pacman apt-get dnf zypper apk; do
    if command -v "$pm" >/dev/null 2>&1; then
        PKG_MANAGER="$pm"
        break
    fi
done
if [ -z "$PKG_MANAGER" ]; then
    echo "No supported package manager found (looked for pacman, apt-get, dnf, zypper, apk). Aborting." >&2
    exit 1
fi
echo "Detected: $PKG_MANAGER"

echo "== Installing system update script (system service, runs as root) =="
sudo install -Dm755 "$SRC_DIR/system-update.sh" /usr/local/bin/system-update.sh
sudo install -Dm644 "$SRC_DIR/system-update.service" /etc/systemd/system/system-update.service
sudo install -Dm644 "$SRC_DIR/system-update.timer" /etc/systemd/system/system-update.timer

TMP_LOGROTATE="$(mktemp)"
cat > "$TMP_LOGROTATE" <<EOF
/var/log/system-update.log {
    weekly
    rotate 8
    compress
    missingok
    notifempty
    create 0644 root root
}
EOF

if [ "$PKG_MANAGER" = "pacman" ] && command -v yay >/dev/null 2>&1; then
    echo "== Arch/Manjaro with yay detected: setting up AUR update path =="

    echo "== Installing yay auto-update script =="
    sudo install -Dm755 "$SRC_DIR/yay-autoupdate.sh" /usr/local/bin/yay-autoupdate.sh

    echo "== Installing yay auto-update user units (runs as $USER_NAME, not root) =="
    install -Dm644 "$SRC_DIR/yay-autoupdate.service" "$HOME/.config/systemd/user/yay-autoupdate.service"
    install -Dm644 "$SRC_DIR/yay-autoupdate.timer" "$HOME/.config/systemd/user/yay-autoupdate.timer"

    cat >> "$TMP_LOGROTATE" <<EOF

$HOME/.local/state/yay-autoupdate.log {
    weekly
    rotate 8
    compress
    missingok
    notifempty
    create 0644 $USER_NAME $USER_NAME
}
EOF

    echo "== Installing scoped NOPASSWD sudoers rule for pacman (user: $USER_NAME) =="
    TMP_SUDOERS="$(mktemp)"
    cat > "$TMP_SUDOERS" <<EOF
# Allow $USER_NAME to run pacman without a password.
# Needed so the yay-autoupdate user service (running as $USER_NAME) can
# call \`sudo pacman ...\` unattended to sync/install packages.
# $USER_NAME already has full sudo access via a privileged group (with a
# password); this only removes the password step for pacman specifically.
$USER_NAME ALL=(root) NOPASSWD: /usr/bin/pacman
EOF
    sudo visudo -cf "$TMP_SUDOERS"
    sudo install -m 0440 -o root -g root "$TMP_SUDOERS" "/etc/sudoers.d/${USER_NAME}-pacman-noconfirm"
    sudo visudo -c
    rm -f "$TMP_SUDOERS"

    echo "== Enabling linger for $USER_NAME (lets the user timer fire even when logged out) =="
    sudo loginctl enable-linger "$USER_NAME"

    echo "== Enabling user timer (yay) =="
    systemctl --user daemon-reload
    systemctl --user enable --now yay-autoupdate.timer
else
    echo "== No AUR-equivalent layer to set up for $PKG_MANAGER (expected outside Arch/Manjaro) =="
fi

echo "== Installing logrotate config =="
sudo install -Dm644 "$TMP_LOGROTATE" /etc/logrotate.d/system-autoupdate
rm -f "$TMP_LOGROTATE"

echo "== Enabling system timer =="
sudo systemctl daemon-reload
sudo systemctl enable --now system-update.timer

echo
echo "Done. Useful commands:"
echo "  systemctl list-timers system-update.timer"
echo "  journalctl -u system-update.service"
echo "  tail -f /var/log/system-update.log"
echo "  sudo systemctl start system-update.service    # run the update right now"
if [ "$PKG_MANAGER" = "pacman" ] && command -v yay >/dev/null 2>&1; then
echo "  systemctl --user list-timers yay-autoupdate.timer"
echo "  journalctl --user -u yay-autoupdate.service"
echo "  tail -f ~/.local/state/yay-autoupdate.log"
echo "  systemctl --user start yay-autoupdate.service # run AUR update right now"
fi
