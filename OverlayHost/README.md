# Roblox ESP Overlay (.exe)

A **standalone Windows executable** that runs *after* Roblox is loaded and draws an ESP
overlay on top of the Roblox window. It is **external** (a separate program) — it does
**not** inject into or scan Roblox's process memory.

> Authorized use only: your own experience, or a friend's experience where you have
> permission (e.g. testing their custom anti-cheat). Do not use against third parties;
> that violates Roblox ToS and will get accounts banned.

## Build (on Windows)

Requires .NET 8 SDK (https://dotnet.microsoft.com/download).

```bat
cd OverlayHost
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true
```

Output: `OverlayHost\bin\Release\net8.0-windows\win-x64\publish\RobloxEspOverlay.exe`
(plus `ReactUi/dist` copied next to it — see below).

The React settings UI is a self-contained `index.html` (no node build needed). After
publishing, copy the `OverlayHost/ReactUi/dist` folder next to the exe so the app can
load `dist/index.html`.

## Run

1. Launch Roblox and join your (or your friend's) experience.
2. Run `RobloxEspOverlay.exe`.
3. The overlay attaches to the Roblox window automatically. The settings panel appears
   top-left. Use **Ctrl** to hide/show the overlay.

## Features

- Box ESP: corner / full / 3D
- Skeleton ESP (auto biped; or supply bones)
- Chams-style outline
- Health bars, tracers (bottom/center/mouse origin), names + distance
- Team check, rainbow, distance limit, performance mode
- Config save/load (`esp_config.json` next to the exe)
- Clean shutdown (restores nothing in-game since it's external)

## Where does entity data come from?

The overlay is engine-agnostic. A **data provider** supplies frames. Three ship:

| Provider | Source | Notes |
|----------|--------|-------|
| `demo`   | built-in mock | moving fake players; tune visuals with no game connection |
| `pipe`   | `\\.\pipe\esp_test` | your in-game script writes JSON frames |
| `tcp`    | `127.0.0.1:13337` | same JSON frames over TCP |

Set `Provider`, `PipeName`, `TcpHost`, `TcpPort` in `esp_config.json`.

### Frame JSON protocol (one JSON object per line, UTF-8)

```json
{
  "Camera": {
    "Position": {"X":0,"Y":6,"Z":-24},
    "Forward": {"X":0,"Y":0,"Z":1},
    "Up": {"X":0,"Y":1,"Z":0},
    "Right": {"X":1,"Y":0,"Z":0},
    "FovDegrees": 70, "ViewW": 1920, "ViewH": 1080, "Near": 0.1, "Far": 1000
  },
  "Entities": [
    {
      "Name": "Player_1", "Team": "Blue", "IsTeammate": true,
      "Health": 80, "MaxHealth": 100, "Rig": "R15",
      "Root": {"X":10,"Y":3,"Z":6}, "Head": {"X":10,"Y":5.2,"Z":6},
      "Feet": {"X":10,"Y":0,"Z":6}, "Height": 5, "Width": 2,
      "Bones": []
    }
  ]
}
```

For anti-cheat testing, your friend's experience can publish this from a `LocalScript`
(see `sample_ingame_pipe_feed.lua`). This is the **consented** channel — no memory
scanning involved. His anti-cheat can then detect the *external reader* however he
wants; this tool simply connects to the pipe/socket.

## Files

- `OverlayHost/OverlayHost.csproj` — project
- `OverlayHost/Program.cs` — entry, provider selection, Ctrl hotkey, shutdown
- `OverlayHost/OverlayForm.cs` — transparent overlay window (tracks Roblox)
- `OverlayHost/Renderer.cs` — ESP drawing (box/skeleton/chams/health/tracer/name)
- `OverlayHost/Providers.cs` — Demo / Pipe / Tcp providers
- `OverlayHost/Settings.cs` — tunables + JSON save/load
- `OverlayHost/Model.cs` — Entity/Frame/Camera model
- `OverlayHost/Project.cs` — world→screen projection + colors
- `OverlayHost/ReactUi/dist/index.html` — settings UI
- `sample_ingame_pipe_feed.lua` — example in-game feed (Roblox Luau, for authorized use)
