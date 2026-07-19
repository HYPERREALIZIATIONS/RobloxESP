namespace RobloxEspOverlay;

/// <summary>
/// A single tracked entity (player) supplied by a data provider.
/// All coordinates are in Roblox WORLD space; the renderer projects them
/// to screen using the camera matrices supplied alongside.
/// This is engine-agnostic: the provider decides where the data comes from
/// (demo, named pipe, TCP, or your own consented game API).
/// </summary>
public class Entity
{
    public string Name { get; set; } = "Player";
    public string Team { get; set; } = "";
    public bool IsTeammate { get; set; }
    public float Health { get; set; } = 100f;
    public float MaxHealth { get; set; } = 100f;
    public RigKind Rig { get; set; } = RigKind.R15;

    // World-space positions (Roblox coordinates: Y up, units = studs)
    public Vec3 Root { get; set; }       // humanoid root
    public Vec3 Head { get; set; }       // head top-ish
    public Vec3 Feet { get; set; }       // ground at root
    public float Height { get; set; } = 5f; // box height in studs (auto if 0)
    public float Width { get; set; } = 2f;  // box width in studs (auto if 0)

    // Optional explicit bone joints for skeleton ESP (world space).
    // If empty, the renderer derives a simple biped skeleton from Root/Head/Feet.
    public List<Bone> Bones { get; set; } = new();
}

public class Bone
{
    public Vec3 A { get; set; }
    public Vec3 B { get; set; }
}

public enum RigKind { R6, R15 }

public struct Vec3(float x, float y, float z)
{
    public float X = x, Y = y, Z = z;
}

/// <summary>
/// Camera description used to project world -> screen.
/// The provider supplies these (e.g. from the game's camera, or a fixed demo camera).
/// </summary>
public class CameraState
{
    public Vec3 Position { get; set; } = new(0, 5, -20);
    public Vec3 Forward { get; set; } = new(0, 0, 1);
    public Vec3 Up { get; set; } = new(0, 1, 0);
    public Vec3 Right { get; set; } = new(1, 0, 0);
    public float FovDegrees { get; set; } = 70f;
    public int ViewW { get; set; } = 1920;
    public int ViewH { get; set; } = 1080;
    public float Near { get; set; } = 0.1f;
    public float Far { get; set; } = 1000f;
}

public class Frame
{
    public CameraState Camera { get; set; } = new();
    public List<Entity> Entities { get; set; } = new();
}
