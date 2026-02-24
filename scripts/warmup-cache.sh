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
GAME_DIR_HOST="${GAME_DIR_HOST:-$CROSSOVER_BOTTLE_PATH/drive_c/Program Files (x86)/Steam/steamapps/common/Call of Duty World at War}"
GAME_EXE_WIN="${GAME_EXE_WIN:-C:\\Program Files (x86)\\Steam\\steamapps\\common\\Call of Duty World at War\\CoDWaW.exe}"
CONSOLE_LOG="${CONSOLE_LOG:-$GAME_DIR_HOST/main/console.log}"
CACHE_FILE="${CACHE_FILE:-$CROSSOVER_BOTTLE_PATH/drive_c/Program Files (x86)/Steam/steamapps/shadercache/10090/DXVK_state_cache/CoDWaW.dxvk-cache}"
CRASH_MARKER="${CRASH_MARKER:-$CROSSOVER_BOTTLE_PATH/drive_c/users/$WINE_USER/AppData/Local/Activision/CoDWaW/__CoDWaW}"
LOG_FILE="${LOG_FILE:-$REPO_ROOT/out/warmup-cache.log}"

PASSES="${1:-1}"
DWELL_SEC="${2:-3}"
POLL_SEC=2
MIN_RUNTIME_SEC=10
TIMEOUT_SEC=30
STOP_DELTA_BYTES=1024

SP_MAPS=(
  ber1 ber2 ber3 ber3b
  mak pby_fly
  pel1 pel1a pel1b pel2
  see1 see2
  sniper
  oki2 oki3
)

mkdir -p "$(dirname "$LOG_FILE")"

cache_size() {
  stat -f '%z' "$CACHE_FILE" 2>/dev/null || echo 0
}

kill_game() {
  "$WINE_BIN" --bottle "$BOTTLE_NAME" taskkill /F /IM CoDWaW.exe >/dev/null 2>&1 || true
}

clear_crash_marker() {
  rm -f "$CRASH_MARKER" >/dev/null 2>&1 || true
}

dismiss_safe_mode_popup() {
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
}

wait_until_ready() {
  local map="$1"
  local tries=$((TIMEOUT_SEC / POLL_SEC))
  local start_sec="$SECONDS"

  for ((i=1; i<=tries; i++)); do
    dismiss_safe_mode_popup

    if ! pgrep -if "CoDWaW.exe" >/dev/null; then
      echo "process_exited_early"
      return 1
    fi

    if [ -f "$CONSOLE_LOG" ] && rg -q "LOADING\.\.\. maps/${map}\.d3dbsp|maps/${map}\.d3dbsp" "$CONSOLE_LOG"; then
      echo "map_loaded"
      return 0
    fi

    if [ $((SECONDS - start_sec)) -ge "$MIN_RUNTIME_SEC" ]; then
      echo "runtime_reached"
      return 0
    fi

    sleep "$POLL_SEC"
  done

  echo "timeout"
  return 1
}

run_map() {
  local map="$1"
  local before after delta state

  before="$(cache_size)"
  clear_crash_marker
  : > "$CONSOLE_LOG"

  (
    "$WINE_BIN" --bottle "$BOTTLE_NAME" --no-wait "$GAME_EXE_WIN" \
      +set logfile 2 \
      +set developer 1 \
      +set com_introPlayed 1 \
      +set com_startupIntroPlayed 1 \
      +set ui_autoContinue 1 \
      +exec autoexec.cfg \
      +map "$map" \
      >/tmp/waw-warmup-${map}.log 2>&1 &
  ) || true

  state="$(wait_until_ready "$map" || true)"

  if [ "$state" = "map_loaded" ] || [ "$state" = "runtime_reached" ]; then
    sleep "$DWELL_SEC"
  else
    sleep 1
  fi

  kill_game
  clear_crash_marker
  sleep 1

  after="$(cache_size)"
  delta=$((after - before))

  echo "map=$map state=$state before=$before after=$after delta=$delta"
  echo "$delta"
}

{
  echo "=== WaW cache warmup start: $(date) ==="
  echo "passes=$PASSES dwell=${DWELL_SEC}s timeout=${TIMEOUT_SEC}s min_runtime=${MIN_RUNTIME_SEC}s"
  echo "cache_initial=$(cache_size)"

  kill_game
  clear_crash_marker
  sleep 1

  total_delta=0

  for ((pass=1; pass<=PASSES; pass++)); do
    pass_delta=0
    echo "--- pass=$pass ---"

    for map in "${SP_MAPS[@]}"; do
      out="$(run_map "$map")"
      echo "$out" | head -n 1
      d="$(echo "$out" | tail -n 1)"
      pass_delta=$((pass_delta + d))
      total_delta=$((total_delta + d))
    done

    echo "pass=$pass delta=$pass_delta"

    if [ "$pass_delta" -le "$STOP_DELTA_BYTES" ]; then
      echo "stopping_early: pass delta <= ${STOP_DELTA_BYTES} bytes"
      break
    fi
  done

  clear_crash_marker
  echo "cache_final=$(cache_size)"
  echo "total_delta=$total_delta"
  echo "=== WaW cache warmup end: $(date) ==="
} | tee "$LOG_FILE"
