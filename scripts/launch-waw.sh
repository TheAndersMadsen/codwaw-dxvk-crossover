#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Optional env overrides via .env
if [ -f "$REPO_ROOT/.env" ]; then
  source "$REPO_ROOT/.env"
fi

WINE_BIN="${WINE_BIN:-/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine}"
BOTTLE_NAME="${BOTTLE_NAME:-Steam}"
CROSSOVER_BOTTLE_PATH="${CROSSOVER_BOTTLE_PATH:-$HOME/Library/Application Support/CrossOver/Bottles/$BOTTLE_NAME}"
WINE_USER="${WINE_USER:-crossover}"
GAME_EXE_WIN="${GAME_EXE_WIN:-C:\\Program Files (x86)\\Steam\\steamapps\\common\\Call of Duty World at War\\CoDWaW.exe}"
CRASH_MARKER="${CRASH_MARKER:-$CROSSOVER_BOTTLE_PATH/drive_c/users/$WINE_USER/AppData/Local/Activision/CoDWaW/__CoDWaW}"

if [ ! -x "$WINE_BIN" ]; then
  echo "Wine binary not found: $WINE_BIN"
  exit 1
fi

# Prevent the Safe Mode popup.
rm -f "$CRASH_MARKER" >/dev/null 2>&1 || true

# Fallback guard: auto-click "No" if Safe Mode dialog still appears.
(
  for _i in {1..10}; do
    osascript <<'APPLESCRIPT' >/dev/null 2>&1 || true
    tell application "System Events"
      repeat with p in (every process whose visible is true)
        try
          repeat with w in windows of p
            if (name of w as text) is "Run In Safe Mode?" then
              click button "No" of w
            end if
          end repeat
        end try
      end repeat
    end tell
APPLESCRIPT
    sleep 2
  done
) &

"$WINE_BIN" --bottle "$BOTTLE_NAME" --no-wait "$GAME_EXE_WIN" \
  +set com_introPlayed 1 \
  +set com_startupIntroPlayed 1 \
  +set ui_autoContinue 1 \
  +exec autoexec.cfg \
  "$@"
