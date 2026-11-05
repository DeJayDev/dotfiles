#!/bin/sh

echo "[.files] - Setting up Claude session backups..."

if [ "$(uname)" != "Darwin" ]; then
  if [ ! -e /dev/tpmrm0 ]; then
    echo "[.files] - ERROR: no TPM at /dev/tpmrm0, this host can't be hardware-bound; skipping Claude backups" >&2
    exit 0
  fi

  if command -v apt >/dev/null 2>&1; then
    sudo apt update && sudo apt install -y restic age golang-go
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --noconfirm --needed restic age go
  fi

  case "$(age --version)" in
    v1.[0-2].*|1.[0-2].*)
      echo "[.files] - ERROR: age $(age --version) is too old, Claude backups need age 1.3+" >&2
      exit 1
      ;;
  esac

  GOBIN="$HOME/.local/bin" go install github.com/foxboron/age-plugin-tpm/cmd/age-plugin-tpm@latest
fi

echo "[.files] - Building claude-backup"
go build -C "$HOME/.config/claude-backup" -o "$HOME/.local/bin/claude-backup" .

if [ "$(uname)" = "Darwin" ]; then
  plist="$HOME/Library/LaunchAgents/com.dejaydev.claude-backup.plist"
  mkdir -p "$HOME/Library/LaunchAgents"
  cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.dejaydev.claude-backup</string>
  <key>ProgramArguments</key>
  <array>
    <string>$HOME/.local/bin/claude-backup</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
  </dict>
  <key>StartInterval</key>
  <integer>43200</integer>
</dict>
</plist>
EOF
  launchctl bootout "gui/$(id -u)/com.dejaydev.claude-backup" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$plist"
  exit 0
fi

units="$HOME/.config/systemd/user"
mkdir -p "$units"
cat > "$units/claude-backup.service" <<EOF
[Unit]
Description=Back up Claude Code sessions with restic

[Service]
Type=oneshot
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=%h/.local/bin/claude-backup
EOF
cat > "$units/claude-backup.timer" <<EOF
[Unit]
Description=Back up Claude Code sessions every 12h

[Timer]
OnCalendar=*-*-* 00/12:00
Persistent=true

[Install]
WantedBy=timers.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now claude-backup.timer
