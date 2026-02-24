#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PATCHED_DLL="$REPO_ROOT/dll/d3d9.dll"
BOTTLES_ROOT_DEFAULT="$HOME/Library/Application Support/CrossOver/Bottles"
PROFILE_NAME_DEFAULT='$$$'

LAUNCH_OPTIONS='+set com_introPlayed 1 +set com_startupIntroPlayed 1 +set ui_autoContinue 1 +exec autoexec.cfg'

say() {
  printf '%s\n' "$1"
}

warn() {
  printf 'WARNING: %s\n' "$1"
}

die() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

prompt_yes_no() {
  local prompt="$1"
  local default_no="${2:-1}"
  local reply=""

  printf '%s' "$prompt"
  IFS= read -r reply || true

  if [ -z "$reply" ]; then
    [ "$default_no" -eq 1 ] && return 1 || return 0
  fi

  case "$reply" in
    y|Y|yes|YES) return 0 ;;
    n|N|no|NO) return 1 ;;
    *) return 1 ;;
  esac
}

detect_game_dirs() {
  local bottles_root="$1"
  typeset -a candidates
  typeset -a dirs
  typeset -A seen
  local exe dir

  [ -d "$bottles_root" ] || return 0

  while IFS= read -r exe; do
    candidates+=("$exe")
  done < <(find "$bottles_root" -type f -name 'CoDWaW.exe' 2>/dev/null)

  while IFS= read -r exe; do
    candidates+=("$exe")
  done < <(find "$bottles_root" -type f -name 'CoDWaWmp.exe' 2>/dev/null)

  for exe in "${candidates[@]}"; do
    dir="$(dirname "$exe")"
    if [ -z "${seen[$dir]-}" ]; then
      seen[$dir]=1
      dirs+=("$dir")
    fi
  done

  printf '%s\n' "${dirs[@]}"
}

pick_game_dir() {
  local game_dir=""
  typeset -a found_dirs
  local i choice

  while IFS= read -r game_dir; do
    [ -n "$game_dir" ] && found_dirs+=("$game_dir")
  done < <(detect_game_dirs "$BOTTLES_ROOT_DEFAULT")

  if [ "${#found_dirs[@]}" -eq 0 ]; then
    say "Could not auto-find WaW in CrossOver bottles."
    printf 'Enter full path to your WaW folder (contains CoDWaW.exe): '
    IFS= read -r game_dir
    [ -n "$game_dir" ] || die "No game directory provided."
    printf '%s\n' "$game_dir"
    return 0
  fi

  if [ "${#found_dirs[@]}" -eq 1 ]; then
    printf '%s\n' "${found_dirs[1]}"
    return 0
  fi

  say "Multiple WaW installs found:"
  for ((i=1; i<=${#found_dirs[@]}; i++)); do
    printf '  %d) %s\n' "$i" "${found_dirs[$i]}"
  done
  printf 'Choose install [1-%d]: ' "${#found_dirs[@]}"
  IFS= read -r choice
  [[ "$choice" =~ '^[0-9]+$' ]] || die "Invalid selection."
  [ "$choice" -ge 1 ] && [ "$choice" -le "${#found_dirs[@]}" ] || die "Selection out of range."
  printf '%s\n' "${found_dirs[$choice]}"
}

detect_bottle_path() {
  local game_dir="$1"
  local bottle_path=""

  if [[ "$game_dir" == *"/drive_c/"* ]]; then
    bottle_path="${game_dir%%/drive_c/*}"
  fi

  if [ -z "$bottle_path" ] || [ ! -d "$bottle_path" ]; then
    printf 'Enter full CrossOver bottle path (contains drive_c): '
    IFS= read -r bottle_path
  fi

  [ -d "$bottle_path/drive_c" ] || die "Invalid bottle path: $bottle_path"
  printf '%s\n' "$bottle_path"
}

detect_display_mode() {
  local sp_out ui_line res_line
  local resolution="" hz_raw="" hz_int=""
  local first_ui first_res best_mode

  sp_out="$(system_profiler SPDisplaysDataType 2>/dev/null || true)"

  # Prefer the connected display mode with the highest refresh rate.
  best_mode="$(printf '%s\n' "$sp_out" | sed -nE 's/.*UI Looks like:[[:space:]]*([0-9]+)[[:space:]]*x[[:space:]]*([0-9]+).*@[[:space:]]*([0-9]+(\.[0-9]+)?)Hz.*/\1x\2;\3/p' | awk -F'[x;]' '{ pixels = $1 * $2; printf("%sx%s;%s;%d\n", $1, $2, $3, pixels) }' | sort -t';' -k2,2nr -k3,3nr | head -n1)"

  if [ -n "$best_mode" ]; then
    resolution="${best_mode%%;*}"
    hz_raw="$(printf '%s\n' "$best_mode" | cut -d';' -f2)"
  fi

  ui_line="$(printf '%s\n' "$sp_out" | awk '
    /Main Display:[[:space:]]+Yes/ {print ui; exit}
    /UI Looks like:/ {ui=$0}
  ')"
  res_line="$(printf '%s\n' "$sp_out" | awk '
    /Main Display:[[:space:]]+Yes/ {print res; exit}
    /Resolution:/ {res=$0}
  ')"

  if [ -z "$ui_line" ]; then
    first_ui="$(printf '%s\n' "$sp_out" | awk '/UI Looks like:/ {print; exit}')"
    [ -n "$first_ui" ] && ui_line="$first_ui"
  fi
  if [ -z "$res_line" ]; then
    first_res="$(printf '%s\n' "$sp_out" | awk '/Resolution:/ {print; exit}')"
    [ -n "$first_res" ] && res_line="$first_res"
  fi

  if [ -z "$resolution" ] && [ -n "$ui_line" ]; then
    resolution="$(printf '%s\n' "$ui_line" | sed -nE 's/.*UI Looks like:[[:space:]]*([0-9]+)[[:space:]]*x[[:space:]]*([0-9]+).*/\1x\2/p')"
    hz_raw="$(printf '%s\n' "$ui_line" | sed -nE 's/.*@ ([0-9]+(\.[0-9]+)?)Hz.*/\1/p')"
  fi

  if [ -z "$resolution" ] && [ -n "$res_line" ]; then
    resolution="$(printf '%s\n' "$res_line" | sed -nE 's/.*Resolution:[[:space:]]*([0-9]+)[[:space:]]*x[[:space:]]*([0-9]+).*/\1x\2/p')"
  fi

  [ -n "$resolution" ] || resolution="1920x1080"
  [ -n "$hz_raw" ] || hz_raw="60"

  hz_int="$(awk -v hz="$hz_raw" 'BEGIN { printf("%d", (hz+0.5)) }')"
  [[ "$hz_int" =~ '^[0-9]+$' ]] || hz_int="60"
  [ "$hz_int" -ge 30 ] || hz_int="60"

  printf '%s;%s\n' "$resolution" "$hz_int"
}

detect_profile_dir() {
  local bottle_path="$1"
  local profiles_root profile_dir users_root
  local found_profiles_root=""
  local found_user=""

  users_root="$bottle_path/drive_c/users"
  [ -d "$users_root" ] || die "Users directory not found in bottle: $users_root"

  found_profiles_root="$(find "$users_root" -type d -path '*/AppData/Local/Activision/CoDWaW/players/profiles' 2>/dev/null | head -n 1 || true)"

  if [ -n "$found_profiles_root" ]; then
    profiles_root="$found_profiles_root"
  else
    if [ -d "$users_root/crossover" ]; then
      found_user="crossover"
    else
      found_user="$(find "$users_root" -mindepth 1 -maxdepth 1 -type d | sed -n '1p' | xargs -I{} basename "{}")"
    fi
    [ -n "$found_user" ] || die "Could not detect a Wine user under: $users_root"
    profiles_root="$users_root/$found_user/AppData/Local/Activision/CoDWaW/players/profiles"
    mkdir -p "$profiles_root"
  fi

  if [ -d "$profiles_root/$PROFILE_NAME_DEFAULT" ]; then
    profile_dir="$profiles_root/$PROFILE_NAME_DEFAULT"
  else
    profile_dir="$(find "$profiles_root" -mindepth 1 -maxdepth 1 -type d | head -n 1 || true)"
    if [ -z "$profile_dir" ]; then
      profile_dir="$profiles_root/$PROFILE_NAME_DEFAULT"
      mkdir -p "$profile_dir"
    fi
  fi

  printf '%s\n' "$profile_dir"
}

ensure_setting() {
  local file="$1"
  local key="$2"
  local value="$3"
  local tmp

  [ -f "$file" ] || : > "$file"
  tmp="$(mktemp)"

  awk -v key="$key" -v value="$value" '
    BEGIN { updated = 0 }
    {
      if ($0 ~ ("^seta[[:space:]]+" key "[[:space:]]+\"")) {
        print "seta " key " \"" value "\""
        updated = 1
      } else {
        print
      }
    }
    END {
      if (!updated) {
        print "seta " key " \"" value "\""
      }
    }
  ' "$file" > "$tmp"

  mv "$tmp" "$file"
}

apply_competitive_settings() {
  local cfg="$1"
  local resolution="$2"
  local hz_int="$3"

  ensure_setting "$cfg" "com_introPlayed" "1"
  ensure_setting "$cfg" "com_startupIntroPlayed" "1"
  ensure_setting "$cfg" "ui_autoContinue" "1"
  ensure_setting "$cfg" "r_fullscreen" "1"
  ensure_setting "$cfg" "r_mode" "$resolution"
  ensure_setting "$cfg" "r_customMode" "$resolution"
  ensure_setting "$cfg" "r_aspectRatio" "auto"
  ensure_setting "$cfg" "r_displayRefresh" "$hz_int Hz"
  ensure_setting "$cfg" "r_vsync" "0"
  ensure_setting "$cfg" "com_maxfps" "$hz_int"
  ensure_setting "$cfg" "vid_xpos" "0"
  ensure_setting "$cfg" "vid_ypos" "0"
  ensure_setting "$cfg" "r_motionblur_enable" "0"
  ensure_setting "$cfg" "r_dof_enable" "0"
  ensure_setting "$cfg" "r_distortion" "0"
}

write_autoexec() {
  local target="$1"
  local resolution="$2"
  local hz_int="$3"

  cat > "$target" <<EOCFG
// Auto-generated by setup-waw-crossover.sh
seta com_introPlayed "1"
seta com_startupIntroPlayed "1"
seta ui_autoContinue "1"
seta r_fullscreen "1"
seta r_mode "$resolution"
seta r_customMode "$resolution"
seta r_aspectRatio "auto"
seta r_displayRefresh "$hz_int Hz"
seta r_vsync "0"
seta com_maxfps "$hz_int"
seta vid_xpos "0"
seta vid_ypos "0"
seta r_motionblur_enable "0"
seta r_dof_enable "0"
seta r_distortion "0"
seta r_aaSamples "1"
seta r_picmip "1"
seta r_picmip_bump "1"
seta r_picmip_spec "1"
seta r_picmip_manual "1"
seta r_fastSkin "1"
seta r_texFilterAnisoMax "2"
seta cl_maxpackets "100"
seta snaps "30"
seta rate "25000"
EOCFG
}

write_dxvk_conf() {
  local target="$1"
  local hz_int="$2"

  cat > "$target" <<EODXVK
# Auto-generated by setup-waw-crossover.sh
d3d9.deferSurfaceCreation = True
d3d9.modeCountCompatibility = True
d3d9.maxFrameLatency = 1
d3d9.presentInterval = 0
d3d9.maxFrameRate = $hz_int
EODXVK
}

update_steam_launch_options() {
  local bottle_path="$1"
  local launch_opts="$2"
  typeset -a vdfs
  local base vdf tmp

  for base in \
    "$bottle_path/drive_c/Program Files (x86)/Steam" \
    "$bottle_path/drive_c/Program Files/Steam"; do
    [ -d "$base/userdata" ] || continue
    while IFS= read -r vdf; do
      [ -n "$vdf" ] && vdfs+=("$vdf")
    done < <(find "$base/userdata" -type f -name localconfig.vdf 2>/dev/null)
  done

  if [ "${#vdfs[@]}" -eq 0 ]; then
    warn "No Steam localconfig.vdf found. Set Launch Options manually to:"
    say "  $launch_opts"
    return 0
  fi

  export WAW_LAUNCH_OPTIONS="$launch_opts"

  for vdf in "${vdfs[@]}"; do
    tmp="$(mktemp)"
    perl -0777 -pe '
      my $opts = $ENV{"WAW_LAUNCH_OPTIONS"} // "";
      s{
        ("10090"\s*\{\s*)
        (.*?)
        (\n[ \t]*\})
      }{
        my ($head, $body, $tail) = ($1, $2, $3);
        if ($body =~ /\n[ \t]*"LaunchOptions"[ \t]*"/s) {
          $body =~ s/\n([ \t]*)"LaunchOptions"[ \t]*"[^"]*"/\n$1"LaunchOptions"\t\t"$opts"/s;
        } else {
          $body .= "\n\t\t\t\t\t\t\"LaunchOptions\"\t\t\"$opts\"";
        }
        $head . $body . $tail;
      }sexg;
    ' "$vdf" > "$tmp"
    mv "$tmp" "$vdf"
  done
}

main() {
  local game_dir bottle_path bottle_name
  local detect_out resolution hz_int
  local profile_dir autoexec_profile autoexec_game
  local config_sp config_mp dxvk_conf crash_marker wine_user

  say "== WaWMacSetup: CrossOver auto-setup =="
  game_dir="$(pick_game_dir)"
  [ -d "$game_dir" ] || die "Game directory does not exist: $game_dir"
  if [ ! -f "$game_dir/CoDWaW.exe" ] && [ ! -f "$game_dir/CoDWaWmp.exe" ]; then
    die "No CoDWaW executable found in: $game_dir"
  fi

  bottle_path="$(detect_bottle_path "$game_dir")"
  bottle_name="$(basename "$bottle_path")"

  detect_out="$(detect_display_mode)"
  resolution="${detect_out%%;*}"
  hz_int="${detect_out##*;}"

  say "Detected game dir: $game_dir"
  say "Detected bottle: $bottle_name"
  say "Detected display mode: ${resolution} @ ${hz_int}Hz"

  if prompt_yes_no "Use detected display mode? [Y/n]: " 0; then
    :
  else
    printf 'Enter resolution (e.g. 2560x1440): '
    IFS= read -r resolution
    [[ "$resolution" =~ '^[0-9]+x[0-9]+$' ]] || die "Resolution must look like 2560x1440"
    printf 'Enter refresh rate Hz (e.g. 120): '
    IFS= read -r hz_int
    [[ "$hz_int" =~ '^[0-9]+$' ]] || die "Refresh rate must be a number"
  fi

  profile_dir="$(detect_profile_dir "$bottle_path")"
  autoexec_profile="$profile_dir/autoexec.cfg"
  autoexec_game="$game_dir/autoexec.cfg"
  config_sp="$profile_dir/config.cfg"
  config_mp="$profile_dir/config_mp.cfg"
  dxvk_conf="$game_dir/dxvk.conf"

  wine_user="$(printf '%s\n' "$profile_dir" | sed -E 's#^.*/drive_c/users/([^/]+)/.*#\1#')"
  crash_marker="$bottle_path/drive_c/users/$wine_user/AppData/Local/Activision/CoDWaW/__CoDWaW"

  if [ -f "$PATCHED_DLL" ]; then
    if prompt_yes_no "Patch d3d9.dll with repo DLL now? [y/N]: " 1; then
      cp "$PATCHED_DLL" "$game_dir/d3d9.dll"
      say "Patched: $game_dir/d3d9.dll"
      shasum -a 256 "$game_dir/d3d9.dll"
    else
      say "Skipping DLL patch."
    fi
  else
    warn "Patched DLL not found at: $PATCHED_DLL"
  fi

  write_autoexec "$autoexec_profile" "$resolution" "$hz_int"
  cp "$autoexec_profile" "$autoexec_game"

  apply_competitive_settings "$config_sp" "$resolution" "$hz_int"
  apply_competitive_settings "$config_mp" "$resolution" "$hz_int"
  write_dxvk_conf "$dxvk_conf" "$hz_int"

  rm -f "$crash_marker" >/dev/null 2>&1 || true
  update_steam_launch_options "$bottle_path" "$LAUNCH_OPTIONS"

  cat > "$REPO_ROOT/configs/steam-launch-options.txt" <<EOLAUNCH
$LAUNCH_OPTIONS
EOLAUNCH


  say ""
  say "Setup complete."
  say "Applied mode: ${resolution} @ ${hz_int}Hz fullscreen"
  say "Profile dir: $profile_dir"
  say "Game dir: $game_dir"
  say ""
  say "Launch normally from CrossOver."
}

main "$@"
