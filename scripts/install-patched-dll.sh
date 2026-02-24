#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Optional env overrides via .env
if [ -f "$REPO_ROOT/.env" ]; then
  source "$REPO_ROOT/.env"
fi

BOTTLE_NAME="${BOTTLE_NAME:-Steam}"
CROSSOVER_BOTTLE_PATH="${CROSSOVER_BOTTLE_PATH:-$HOME/Library/Application Support/CrossOver/Bottles/$BOTTLE_NAME}"
GAME_DIR_HOST="${GAME_DIR_HOST:-$CROSSOVER_BOTTLE_PATH/drive_c/Program Files (x86)/Steam/steamapps/common/Call of Duty World at War}"
PATCHED_DLL="$REPO_ROOT/dll/d3d9.dll"
TARGET_DLL="$GAME_DIR_HOST/d3d9.dll"

if [ ! -f "$PATCHED_DLL" ]; then
  echo "Missing patched DLL: $PATCHED_DLL"
  exit 1
fi

if [ ! -d "$GAME_DIR_HOST" ]; then
  echo "Game directory not found: $GAME_DIR_HOST"
  echo "Set BOTTLE_NAME, CROSSOVER_BOTTLE_PATH, or GAME_DIR_HOST in .env"
  exit 1
fi

cp "$PATCHED_DLL" "$TARGET_DLL"
echo "Installed patched DLL to: $TARGET_DLL"
shasum -a 256 "$TARGET_DLL"
