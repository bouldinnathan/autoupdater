# autoupdater

Daily systemd timers that keep a Linux box's packages up to date automatically:
official repo packages via your distro's package manager, plus AUR packages via
`yay` on Arch-based systems.

## Supported distros

| Package manager | Distro family |
|---|---|
| `pacman` (+ `yay` for AUR, if installed) | Arch, Manjaro, EndeavourOS, Garuda, ArcoLinux |
| `apt` | Debian, Ubuntu, Mint, Pop!_OS, Raspberry Pi OS |
| `dnf` | Fedora, RHEL, Rocky Linux, AlmaLinux |
| `zypper` | openSUSE Leap / Tumbleweed |
| `apk` | Alpine (only if it's running systemd — most Alpine installs use OpenRC and aren't supported) |

Requires systemd. `install.sh` detects your package manager and init system
and refuses to run if neither is recognized, rather than silently doing nothing.

**Not supported on purpose:** Gentoo (unattended source builds are slow and
fragile), NixOS (declarative rebuild model doesn't fit an imperative "run the
update" script), non-systemd inits (Alpine's default OpenRC, Void's runit).

## Install

```console
$ git clone https://github.com/bouldinnathan/autoupdater.git
$ cd autoupdater
$ ./install.sh
```

Example output on Arch/Manjaro with `yay` already installed:

```
== Checking for systemd ==
== Detecting package manager ==
Detected: pacman
== Installing system update script (system service, runs as root) ==
[sudo] password for nathan:
== Arch/Manjaro with yay detected: setting up AUR update path ==
== Installing yay auto-update script ==
== Installing yay auto-update user units (runs as nathan, not root) ==
== Installing scoped NOPASSWD sudoers rule for pacman (user: nathan) ==
== Enabling linger for nathan (lets the user timer fire even when logged out) ==
== Enabling user timer (yay) ==
== Installing logrotate config ==
== Enabling system timer ==

Done. Useful commands:
  systemctl list-timers system-update.timer
  journalctl -u system-update.service
  tail -f /var/log/system-update.log
  sudo systemctl start system-update.service    # run the update right now
  systemctl --user list-timers yay-autoupdate.timer
  journalctl --user -u yay-autoupdate.service
  tail -f ~/.local/state/yay-autoupdate.log
  systemctl --user start yay-autoupdate.service # run AUR update right now
```

On Debian/Ubuntu/Fedora/openSUSE/Alpine, or Arch without `yay` installed, only
the `system-update.timer` block runs — there's no AUR-equivalent step.

## What gets installed

| Unit | Runs as | Schedule | Does |
|---|---|---|---|
| `system-update.timer` / `.service` | root, system unit | daily 03:00 (±5 min) | Full package upgrade via whichever of `pacman`/`apt`/`dnf`/`zypper`/`apk` is present |
| `yay-autoupdate.timer` / `.service` | you, user unit | daily 03:15 (±5 min) | `yay -Syu` — Arch/Manjaro with `yay` only |
| `/etc/sudoers.d/$USER-pacman-noconfirm` | — | — | Arch/Manjaro only. Lets `yay` call `sudo pacman` unattended, without a password |

The yay timer runs 15 minutes after the system timer to avoid both processes
touching the pacman database at once.

`Persistent=true` is set on both timers: if the machine is off at the
scheduled time, the update runs shortly after the next boot instead of being
skipped entirely.

## Checking on it

```console
$ systemctl list-timers system-update.timer
NEXT                        LEFT LAST PASSED UNIT
Sat 2026-08-08 03:04:12 CDT   5h  -    -      system-update.timer

$ journalctl -u system-update.service --no-pager | tail -5
Starting system update: 2026-08-07T20:44:14-05:00
:: Synchronizing package databases...
:: Starting full system upgrade...
 there is nothing to do
Finished system update: 2026-08-07T20:44:15-05:00

$ tail -f /var/log/system-update.log
```

## Running it on demand

```console
$ sudo systemctl start system-update.service
$ systemctl --user start yay-autoupdate.service   # Arch/Manjaro with yay only
```

## Logs

- `/var/log/system-update.log` — repo package updates, rotated weekly, 8 weeks kept
- `~/.local/state/yay-autoupdate.log` — AUR updates, Arch/Manjaro only, same rotation

Both are also captured in the systemd journal (`journalctl -u ...` /
`journalctl --user -u ...`), so the log files are a convenience, not the only copy.

## Uninstall

```console
$ sudo systemctl disable --now system-update.timer
$ sudo rm -f /etc/systemd/system/system-update.{service,timer} \
             /usr/local/bin/system-update.sh /var/log/system-update.log*
$ sudo systemctl daemon-reload

# Arch/Manjaro with yay only:
$ systemctl --user disable --now yay-autoupdate.timer
$ rm -f ~/.config/systemd/user/yay-autoupdate.{service,timer} ~/.local/state/yay-autoupdate.log*
$ sudo rm -f /usr/local/bin/yay-autoupdate.sh /etc/sudoers.d/$USER-pacman-noconfirm
$ systemctl --user daemon-reload
```

## Security note

On Arch/Manjaro, `install.sh` adds a `NOPASSWD` sudoers rule scoped to the
`pacman` binary only — not full root — so `yay` can install AUR packages
unattended. Your user already has full `sudo` access via your admin group
(with a password); this just removes the password step for `pacman`
specifically. Check `/etc/sudoers.d/$USER-pacman-noconfirm` to see exactly
what it grants.
