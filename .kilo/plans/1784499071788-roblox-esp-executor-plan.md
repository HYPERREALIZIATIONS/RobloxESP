# Universal Roblox ESP (Executor Lua) — Implementation Plan

## Scope & constraints
- Single self-contained Lua script for a Roblox **executor** using the Synapse/Krnl-style `Drawing` library (e.g. `Drawing.new("Square")`, `"Text"`, `"Line"`, `"Circle"`, `"Quad"`).
- Intended for **your own / explicitly permitted** games only. No remote auto-update, no HTTP loading.
- Works with both **R6 and R15** characters via rig-type detection.

## Architecture
- `local ESP = {}` module-ish table holding settings, player records, and lifecycle.
- Per-player record created lazily on `PlayerAdded` / when character spawns; holds Drawing objects for each enabled feature and cached originals for chams.
- One main update loop driven by `RunService.RenderStepped` (or `Heartbeat`) that:
  - iterates `Players:GetPlayers()`, skips `LocalPlayer`, applies team check + distance cull.
  - computes world→screen with `CurrentCamera:WorldToViewportPoint(root.Position)`.
  - updates/positions/colors all enabled Drawing objects; hides them when off-screen or culled.
- Cleanup on `PlayerRemoving` and `CharacterRemoving`: `:Remove()` all drawings, restore chams originals.

## Rig handling
- `Humanoid.RigType` (`Enum.HumanoidRigType.R6` / `.R15`) selects:
  - **Box origin**: bounding from HumanoidRootPart (or computed torso extents).
  - **Skeleton bone pairs**: named joints (R15: Head/UpperTorso/LowerTorso/UpperArm*/LowerArm*/Hand*/UpperLeg*/LowerLeg*/Foot*; R6: Head/Torso/Left/Right Arm+Leg). Resolve joints via `character:FindFirstChild(name)` and `:GetJointPosition()`-style midpoints or direct part CFrame.

## Features (all toggleable)
- **Box ESP** modes: `corner` (4 L-shaped brackets), `full` (rectangle), `3D` (project 8 cube corners, draw 12 edges via Lines). Switch via setting.
- **Skeleton ESP**: Lines between resolved bone positions; thickness + color from settings.
- **Chams**: override each `BasePart.Color` + `Transparency` (store originals, restore on unload / toggle off). Team-aware.
- **Health bar**: vertical bar positioned beside box, height ∝ `Humanoid.Health/MaxHealth`, color gradient optional.
- **Tracers**: Line from configurable screen origin (default bottom-center) to target; color/thickness settings.
- **Names**: `Drawing.Text` above head with distance suffix.
- **Rainbow**: hsv-based color rotation applied to selected features when enabled (shared tick-based hue).

## Settings (tunable via UI)
- `teamCheck` (bool), `distanceLimit` (number / 0 = off)
- `boxMode` (`corner`|`full`|`3D`), `boxColor`, `boxThickness`, `boxTransparency`
- `skeleton` (bool) + color/thickness
- `chams` (bool) + color/transparency
- `healthbar` (bool) + colors
- `tracer` (bool) + origin mode + color/thickness
- `names` (bool) + color/size
- `rainbow` (bool) + speed
- `performanceMode` (bool): skips skeleton+chams, lowers update cadence, reuses objects.
- `tracerOrigin`: `bottom` | `center` | `mouse`
- `minimized` (bool, toggled by Ctrl)

## UI
- Lightweight in-game UI built from Drawing objects (panels + clickable rows) OR a minimal `ScreenGui` with draggable panel — pick Drawing-based to stay executor-portable.
- Controls: color pickers (hue slider), sliders for thickness/transparency/distance, toggle rows, mode selector, Save/Load buttons, Minimize (also Ctrl hotkey).
- Open/close or minimize with **Ctrl**; visibility toggles all feature draws off when minimized.

## Config save/load
- `saveConfig(path)`: `writefile(path, game:GetService("HttpService"):JSONEncode(settings))`.
- `loadConfig(path)`: `readfile` + decode + apply; guard missing file.
- Default path e.g. `"esp_config.json"`.

## Lifecycle
- `ESP:Unload()` — set running=false, disconnect RenderStepped + player events, `:Remove()` all drawings, restore chams, destroy UI.
- Defensive: wrap per-frame work in `pcall`; skip players with missing character/humanoid.

## Validation
- Load in a permitted test place; spawn/insert **R6 and R15** dummies.
- Verify each box mode, skeleton, chams, health bar, tracer, names, rainbow.
- Confirm team check hides teammates and distance limit culls far targets.
- Save config, reload script, Load config → settings persist.
- Press Ctrl → minimizes; Unload → no leftover drawings, chams restored.

## Risks / notes
- Chams and ESP in other players' games violate Roblox ToS; use only where permitted.
- `WorldToViewportPoint` behind-camera handling: check `.Z`/on-screen flag, hide if behind.
- Performance mode is the safe default for low-end sessions.
