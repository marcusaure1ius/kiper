#!/bin/zsh
# Installs (or removes with --uninstall) a launchd job that runs
# refresh-device.sh at 10:00, 15:00 and 21:00 every day and at login.
# The script itself decides whether a reinstall is due (every 3+ days).

set -eu

LABEL="ru.kiper.refresh-device"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
SCRIPT="${0:A:h}/refresh-device.sh"

if [[ "${1:-}" == "--uninstall" ]]; then
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  rm -f "$PLIST"
  print "Removed $LABEL"
  exit 0
fi

chmod +x "$SCRIPT"
mkdir -p "${PLIST:h}"
cat >"$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>/bin/zsh</string><string>$SCRIPT</string></array>
  <key>StartCalendarInterval</key>
  <array>
    <dict><key>Hour</key><integer>10</integer><key>Minute</key><integer>0</integer></dict>
    <dict><key>Hour</key><integer>15</integer><key>Minute</key><integer>0</integer></dict>
    <dict><key>Hour</key><integer>21</integer><key>Minute</key><integer>0</integer></dict>
  </array>
  <key>RunAtLoad</key><true/>
  <key>ProcessType</key><string>Background</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
print "Installed $LABEL → $PLIST"
print "Log: ~/Library/Logs/kiper-refresh.log"
