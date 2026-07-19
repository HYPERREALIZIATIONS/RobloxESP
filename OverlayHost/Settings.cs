using System.Text.Json;

namespace RobloxEspOverlay;

/// <summary>
/// All user-tunable settings. Serialized to JSON for save/load.
/// Colors are stored as 0xRRGGBB integers for easy UI binding.
/// </summary>
public class Settings
{
    public bool Enabled { get; set; } = true;
    public bool TeamCheck { get; set; } = true;
    public float DistanceLimit { get; set; } = 0; // 0 = off
    public bool ShowThroughWalls { get; set; } = true; // draw occluded players (dimmed)

    public string BoxMode { get; set; } = "corner"; // corner | full | threed
    public int BoxColor { get; set; } = 0x00FF00;
    public float BoxThickness { get; set; } = 1.5f;
    public float BoxOpacity { get; set; } = 1f;

    public bool Skeleton { get; set; } = true;
    public int SkeletonColor { get; set; } = 0xFFFFFF;
    public float SkeletonThickness { get; set; } = 1.5f;

    public bool Chams { get; set; } = false; // outline-only emulation in external overlay
    public int ChamsColor { get; set; } = 0xFF0000;
    public float ChamsOpacity { get; set; } = 0.5f;

    public bool HealthBar { get; set; } = true;
    public int HealthColor { get; set; } = 0x00FF00;
    public int HealthColorBad { get; set; } = 0xFF0000;

    public bool Tracer { get; set; } = true;
    public string TracerOrigin { get; set; } = "bottom"; // bottom | center | mouse
    public int TracerColor { get; set; } = 0xFFFF00;
    public float TracerThickness { get; set; } = 1.5f;

    public bool Names { get; set; } = true;
    public int NameColor { get; set; } = 0xFFFFFF;
    public float NameSize { get; set; } = 13f;

    public bool Rainbow { get; set; } = false;
    public float RainbowSpeed { get; set; } = 1f;

    public bool PerformanceMode { get; set; } = false;
    public bool Minimized { get; set; } = false;

    // ---- persistence ----
    private static readonly string Path =
        System.IO.Path.Combine(System.AppContext.BaseDirectory, "esp_config.json");

    public void Save()
    {
        try
        {
            var json = JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true });
            System.IO.File.WriteAllText(Path, json);
        }
        catch { /* ignore IO errors */ }
    }

    public static Settings Load()
    {
        try
        {
            if (!System.IO.File.Exists(Path)) return new Settings();
            var json = System.IO.File.ReadAllText(Path);
            var s = JsonSerializer.Deserialize<Settings>(json);
            return s ?? new Settings();
        }
        catch { return new Settings(); }
    }

    // Provider selection (where entity data comes from).
    public string Provider { get; set; } = "demo"; // demo | pipe | tcp
    public string PipeName { get; set; } = "esp_test";
    public string TcpHost { get; set; } = "127.0.0.1";
    public int TcpPort { get; set; } = 13337;
}
