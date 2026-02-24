# Troubleshooting

## Safe Mode popup still appears

Run setup again, or manually remove:

```bash
rm -f "$HOME/Library/Application Support/CrossOver/Bottles/<Bottle>/drive_c/users/<User>/AppData/Local/Activision/CoDWaW/__CoDWaW"
```

## DirectX unrecoverable error

Check:

- `d3d9.dll` in WaW game folder is the patched DXVK DLL (if you chose patch = yes)
- `dxvk.conf` exists next to `CoDWaW.exe`
- CrossOver bottle uses DXVK

## Game starts tiny / wrong resolution

Re-run:

```bash
./scripts/setup-waw-crossover.sh
```

Then confirm the detected resolution/Hz prompt values are correct.

## Warmup shows low cache growth

Normal after cache plateaus. Try 2 passes:

```bash
./scripts/warmup-cache.sh 2 4
```
