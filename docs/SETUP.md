# Setup

## Prerequisites

- macOS with CrossOver installed
- Steam bottle with Call of Duty: World at War installed

## One-step setup

Run:

```bash
./scripts/setup-waw-crossover.sh
```

What it does:

- Finds WaW install path automatically (or asks you to enter it)
- Finds the CrossOver bottle path
- Detects active monitor resolution + refresh rate
- Asks if you want to patch `d3d9.dll` (`y/n`)
- Applies fullscreen/high-Hz config to SP and MP profiles
- Writes `dxvk.conf` in game folder
- Clears Safe Mode crash marker
- Updates Steam launch options for app `10090`

## Optional extras

Manual patch only:

```bash
./scripts/install-patched-dll.sh
```

Direct launch helper:

```bash
./scripts/launch-waw.sh
```

Cache warmup:

```bash
./scripts/warmup-cache.sh 1 3
```
