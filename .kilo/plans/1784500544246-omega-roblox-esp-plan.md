# Omega — External Roblox ESP Overlay (Windows, Python)

## Goal
A Windows-only Python tool, **Omega**, that renders a transparent, click-through ESP overlay on top of the Roblox client by reading process memory externally (no injection). It shows per-player boxes (corner or full, plus optional 3D), tracer lines, name tags, distance, and a health bar; auto-skips teammates and dead players; hides players beyond a configurable max distance; toggles with `P` and exits with `Insert`. Visual settings/colors live at the top of the main script. Includes a setup script that installs missing deps and registers a `stomega` command.

## Confirmed design decisions
- **Overlay stack:** Pygame (SDL) full-screen borderless window with `WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOPMOST` → true transparent click-through (win32 `SetWindowLong`). DPI-aware for Win10/11.
- **Offsets:** Use `robloxmemoryapi` (PyPI) as primary — it bundles current offsets from `offsets.imtheo.lol`. Add a remote fallback fetch from `https://dumper.jonah.cool/offsets.py` and a bundled local `offsets.py` copy. If the primary library fails to resolve the model, attempt the remote fetch, then local fallback. Print a clear "offsets may be stale" warning when falling back.
- **Player data:** Full DataModel traversal via `robloxmemoryapi`: `DataModel.Players.GetPlayers()` → each `player` → `Character` → `Humanoid` (Health, MaxHealth) + `PrimaryPart`/HRP (world position) + `Head`. Use `player.Team`/`TeamColor` for teammate skip, `player.Name`/`DisplayName`, `LocalPlayer` for self-exclusion. Dead = `Health <= 0` or no Character. Camera via `Workspace.CurrentCamera` (CFrame, FieldOfView, ViewportSize) for W2S.

## Platform / admin requirements
- Windows 10 and 11 only. Use `psutil`/`ctypes` to detect OS and abort with a message on non-Windows.
- Expect admin rights: attempt to open the Roblox process with `PROCESS_VM_READ | PROCESS_QUERY_INFORMATION`. If open fails, print "run as Administrator" guidance and retry loop.

## Project structure
```
Omega/
├── omega.py          # Main script: CONFIG block at top, memory read, overlay loop
├── offsets.py        # Bundled fallback offsets (generated from dumper.jonah.cool)
├── offsets_remote.py # (optional) loader that fetches remote offsets
├── setup.bat         # Install deps + register stomega command
├── uninstall.bat     # Remove stomega command + launcher folder
└── README.md         # Usage, hotkeys, troubleshooting
```

## omega.py — layout
1. **CONFIG block (top of file, ~lines 1-80)** — all visual settings & colors, easy to edit:
   - `ENABLE_ESP` (default True), `TOGGLE_KEY = "p"`, `EXIT_KEY = "insert"`.
   - Box mode: `BOX_MODE = "corner" | "full" | "3d"` (string).
   - `SHOW_TRACERS`, `SHOW_NAMES`, `SHOW_DISTANCE`, `SHOW_HEALTHBAR` (bool).
   - `MAX_DISTANCE` (float meters; 0 = unlimited).
   - `SKIP_TEAMMATES`, `SKIP_DEAD` (bool).
   - Tracer origin: `"bottom_center" | "screen_center" | "crosshair"`.
   - Colors as `(R,G,B[,A])`: `COLOR_BOX_ENEMY`, `COLOR_BOX_TEAMMATE`, `COLOR_BOX_DEAD`, `COLOR_TRACER`, `COLOR_NAME`, `COLOR_DISTANCE`, `COLOR_HEALTH_HIGH`, `COLOR_HEALTH_LOW`, `COLOR_HEALTH_BG`.
   - Font size, line thickness, box padding, 3D box depth scale.
2. **Win32 / overlay setup:** pygame init, full-screen `NOFRAME` surface sized to `pygame.display.Info()`; apply `WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOPMOST`; set per-pixel alpha (transparent) background; DPI awareness via `SetProcessDpiAwarenessContext`.
3. **Memory client:** init `RobloxGameClient`; if `failed`, loop-wait for Roblox + admin. Provide `get_players()` returning list of dicts: `{name, display_name, pos(Vector3), health, max_health, team, is_local, is_dead, head_pos, feet_pos}`.
4. **World-to-Screen:** function `w2s(world_vec, camera_cframe, fov, viewport)` → screen x,y + behind-camera flag. Use camera CFrame (right/up/look vectors) and FOV; handle `z <= 0` (behind camera) to skip.
5. **Render functions:** `draw_box_2d`, `draw_box_corner`, `draw_box_3d` (project 8 corners of an axis-aligned humanoid-sized cuboid, draw edges), `draw_tracer`, `draw_name`, `draw_distance`, `draw_healthbar`. Clear surface each frame with transparent fill, draw, `display.update()`.
6. **Main loop:** poll memory each frame (~60fps, time.sleep to throttle); filter out local/teammates(dead); compute distance, skip if > MAX_DISTANCE or dead; draw. Global hotkeys via `keyboard` lib or win32 `RegisterHotKey` for `P` (toggle) and `Insert` (exit). Keep overlay input-transparent.
7. **Graceful handling:** Roblox not running → show small overlay hint "Waiting for Roblox…"; on update/offset mismatch → log warning, attempt remote/local offset refresh.

## offsets handling
- `setup.bat` runs `pip install robloxmemoryapi pygame pywin32 keyboard psutil requests`.
- At startup: try `import robloxmemoryapi` (primary). On failure/version mismatch, `offsets_remote.fetch()` downloads `https://dumper.jonah.cool/offsets.py` to a cache; if offline, import bundled `offsets.py`. Emit a visible console warning when not using the live library.

## setup.bat
- `@echo off`, require admin (self-elevate via `powershell -Command "Start-Process ... -Verb RunAs"` if not elevated).
- `python -m pip install --upgrade pip` then install deps.
- Create `C:\omega-launcher\` containing a `stomega.bat` that runs `python "<full path to omega.py>"`.
- Register `stomega` on PATH: add `C:\omega-launcher` to the user `PATH` via `setx` (so new CMD windows pick it up). Print "open a NEW command window, type stomega".

## uninstall.bat
- Remove `C:\omega-launcher` and strip it from user `PATH`.

## README.md
- Short: what it is, Windows 10/11 + admin, hotkeys (`P` toggle, `Insert` close), `stomega` usage, config location, troubleshooting (run as admin, wait after Roblox loads, offsets-stale warning).
- Disclaimer: educational use only; external memory read, no injection.

## Key risks / notes
- RobloxMemoryAPI is Windows-only and reads the live process; offsets shift on Roblox updates — mitigated by remote+local fallback, but a freshly released update may briefly show no players until offsets catch up.
- `WS_EX_TRANSPARENT` makes the window fully click-through (desired). Hotkeys handled via global `RegisterHotKey`/`keyboard` so they work while Roblox is focused.
- Anti-cheat: external `ReadProcessMemory` is lower-risk than injection but not guaranteed undetectable by all experiences; out of scope to evade detection.

## Validation (on a Windows 10/11 machine with Roblox + admin)
1. Run `setup.bat` as admin → `stomega` works from a new CMD.
2. Launch Roblox game, then `stomega`. Overlay appears, transparent, click-through (game still receives mouse/keyboard).
3. Confirm boxes/tracers/names/distance/health for enemies; teammates skipped; dead players hidden; far players hidden beyond `MAX_DISTANCE`.
4. Press `P` → ESP hides; press `P` → returns. Press `Insert` → closes.
5. Switch `BOX_MODE` and colors in CONFIG; reload → reflected.
6. Simulate offset change: temporarily break primary lib import → confirm remote/local fallback + warning.
```
