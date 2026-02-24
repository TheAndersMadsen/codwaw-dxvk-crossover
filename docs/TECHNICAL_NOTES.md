# Technical Notes

## Goal

Run WaW with DXVK on Apple Silicon (CrossOver) and reduce stutter/launch issues.

## Core approach

1. Use DXVK D3D9 (`d3d9.dll`) instead of WineD3D path.
2. Force stable fullscreen settings in both SP and MP configs.
3. Match frame cap to detected display refresh rate.
4. Persist launch options so normal CrossOver/Steam launch path works.
5. Remove Safe Mode crash marker file between runs.

## Dynamic display logic

`scripts/setup-waw-crossover.sh` reads display data from macOS (`system_profiler SPDisplaysDataType`) and applies:

- `r_mode` and `r_customMode` from detected resolution
- `r_displayRefresh` and `com_maxfps` from detected refresh rate
- `r_fullscreen 1`

No fixed monitor mode is required in source files.

## Cache prewarm

`scripts/warmup-cache.sh` can pre-run SP maps to populate DXVK state cache and reduce first-run hitching.

## Known limits

- Some shaders still compile during real gameplay (especially new MP/zombie scenes).
- If WaW crashes, Safe Mode prompt can still reappear until marker is cleared again.
