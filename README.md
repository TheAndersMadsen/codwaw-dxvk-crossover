# Call of Duty - World at War - Crossover DXVK

Simple DXVK setup for **Call of Duty: World at War** on macOS via **CrossOver**.

## What this repo does

- Auto-detects your CrossOver bottle + WaW install path
- Detects your active monitor resolution + refresh rate automatically
- Applies fullscreen/high-Hz settings to SP + MP config files
- Optionally patches `d3d9.dll` (interactive `y/n` prompt)
- Writes DXVK config tuned to detected refresh rate
- Removes the Safe Mode crash marker

## Quick Start

```bash
cd WaWMacSetup
./scripts/setup-waw-crossover.sh
```

That script is the main entry point.

## Repo Layout

- `scripts/setup-waw-crossover.sh`: one-step installer/configurator (recommended)
- `scripts/install-patched-dll.sh`: manual DLL patch helper
- `scripts/launch-waw.sh`: optional direct launcher with Safe Mode auto-dismiss
- `scripts/warmup-cache.sh`: optional shader/pipeline cache warmup
- `dll/d3d9.dll`: patched DXVK D3D9 DLL
- `configs/`: templates/examples
- `docs/`: setup + troubleshooting + technical notes

## Notes

- The setup script does **not** hardcode monitor values in source; it reads them from the machine running it.
- You can still launch WaW from normal CrossOver/Steam UI after setup.
