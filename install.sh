#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${USER:-$(whoami)}"

echo "== Installing pacman auto-update (system service, runs as root) =="
sudo install -Dm755 "$SRC_DIR/pacman-autoupdate.sh" /usr/local/bin/pacman-autoupdate.sh
sudo install -Dm644 "$SRC_DIR/pacman-autoupdate.service" /etc/systemd/system/pacman-autoupdate.service
sudo install -Dm644 "$SRC_DIR/pacman-autoupdate.timer" /etc/systemd/system/pacman-autoupdate.timer

echo "== Installing yay auto-update script =="
sudo install -Dm755 "$SRC_DIR/yay-autoupdate.sh" /usr/local/bin/yay-autoupdate.sh

echo "== Installing yay auto-update user units (runs as $USER_NAME, not root) =="
install -Dm644 "$SRC_DIR/yay-autoupdate.service" "$HOME/.config/systemd/user/yay-autoupdate.service"
install -Dm644 "$SRC_DIR/yay-autoupdate.timer" "$HOME/.config/systemd/user/yay-autoupdate.timer"

echo "== Installing logrotate config for both logs =="
TMP_LOGROTATE="$(mktemp)"
cat > "$TMP_LOGROTATE" <<EOF
/var/log/pacman-autoupdate.log {
    weekly
    rotate 8
    compress
    missingok
    notifempty
    create 0644 root root
}

$HOME/.local/state/yay-autoupdate.log {
    weekly
    rotate 8
    compress
    missingok
    notifempty
    create 0644 $USER_NAME $USER_NAME
}
EOF
sudo install -Dm644 "$TMP_LOGROTATE" /etc/logrotate.d/system-autoupdate
rm -f "$TMP_LOGROTATE"

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

echo "== Enabling system timer (pacman) =="
sudo systemctl daemon-reload
sudo systemctl enable --now pacman-autoupdate.timer

echo "== Enabling user timer (yay) =="
systemctl --user daemon-reload
systemctl --user enable --now yay-autoupdate.timer

echo
echo "Done. Useful commands:"
echo "  systemctl list-timers pacman-autoupdate.timer"
echo "  systemctl --user list-timers yay-autoupdate.timer"
echo "  journalctl -u pacman-autoupdate.service"
echo "  journalctl --user -u yay-autoupdate.service"
echo "  tail -f /var/log/pacman-autoupdate.log"
echo "  tail -f ~/.local/state/yay-autoupdate.log"
echo "  sudo systemctl start pacman-autoupdate.service   # run pacman update right now"
echo "  systemctl --user start yay-autoupdate.service     # run yay update right now"
