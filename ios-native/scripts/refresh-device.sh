#!/bin/zsh
# Re-signs and reinstalls Kiper on your iPhone so the free-Apple-ID 7-day
# signature never runs out. Data on the phone is kept (it's an update, not a
# fresh install).
#
# Runs from launchd several times a day (see install-schedule.sh) but only does
# real work when the last successful install is older than MIN_AGE_DAYS and the
# phone is reachable (cable, or the same Wi-Fi with "Connect via network").
#
# Usage: refresh-device.sh [--force]

set -u

PROJECT_DIR="${0:A:h:h}"
DEVICE_ID="${KIPER_DEVICE_ID:-00008160-000C4D1E00434036}"
MIN_AGE_DAYS="${KIPER_MIN_AGE_DAYS:-3}"
STATE_DIR="$HOME/Library/Application Support/KiperRefresh"
STAMP="$STATE_DIR/last-success"
LOG="$HOME/Library/Logs/kiper-refresh.log"
BUILD_DIR="$STATE_DIR/build"
APP="$BUILD_DIR/Build/Products/Release-iphoneos/Kiper.app"

mkdir -p "$STATE_DIR" "${LOG:h}"
exec >>"$LOG" 2>&1
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:$PATH"

log() { print -r -- "$(date '+%Y-%m-%d %H:%M:%S') $*"; }
notify() { /usr/bin/osascript -e "display notification \"$2\" with title \"Кипер\" subtitle \"$1\"" >/dev/null 2>&1 || true; }

days_since_success() {
  [[ -f "$STAMP" ]] || { print 999; return }
  print $(( ($(date +%s) - $(stat -f %m "$STAMP")) / 86400 ))
}

age=$(days_since_success)
if [[ "${1:-}" != "--force" && $age -lt $MIN_AGE_DAYS ]]; then
  exit 0   # fresh enough, stay quiet
fi

# Is the phone reachable right now?
if ! xcrun devicectl list devices 2>/dev/null | grep "$DEVICE_ID" | grep -qE "available|connected"; then
  log "skip: iPhone not reachable (last success ${age}d ago)"
  if (( age >= 6 )); then
    notify "Подпись скоро истечёт" "Подключите iPhone к Mac или той же Wi‑Fi — Кипер обновится сам."
  fi
  exit 0
fi

log "building (last success ${age}d ago)"
if ! xcodebuild \
    -project "$PROJECT_DIR/Kiper.xcodeproj" -scheme Kiper -configuration Release \
    -destination "generic/platform=iOS" -derivedDataPath "$BUILD_DIR" \
    -allowProvisioningUpdates -quiet build; then
  log "FAIL: build/signing (often: no connection to Apple — retry later)"
  notify "Не удалось обновить" "Ошибка сборки или подписи. Подробности: ~/Library/Logs/kiper-refresh.log"
  exit 1
fi

log "installing on $DEVICE_ID"
# A locked / sleeping iPhone refuses installs (CoreDeviceError 4016): retry a few times.
installed=0
for attempt in 1 2 3; do
  out=$(xcrun devicectl device install app --device "$DEVICE_ID" "$APP" 2>&1) && { installed=1; break; }
  print -r -- "$out" | tail -3
  if print -r -- "$out" | grep -q "4016"; then
    log "iPhone is locked, retry $attempt/3 in 60s"
    sleep 60
  else
    break
  fi
done
if (( ! installed )); then
  log "FAIL: install"
  notify "Не удалось обновить" "Разблокируйте iPhone — попробую снова в следующий запуск."
  exit 1
fi

touch "$STAMP"
log "OK: installed, signature renewed for 7 days"
notify "Обновлено" "Кипер переподписан ещё на 7 дней."
