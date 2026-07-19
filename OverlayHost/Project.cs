using System.Numerics;

namespace RobloxEspOverlay;

/// <summary>
/// World -> screen projection using a look-at style camera (right-handed, Y up).
/// Roblox uses a right-handed coordinate system with Y up; this matches.
/// </summary>
public static class Project
{
    public static Matrix4x4 View(CameraState c)
    {
        var eye = new Vector3(c.Position.X, c.Position.Y, c.Position.Z);
        var fwd = Vector3.Normalize(new Vector3(c.Forward.X, c.Forward.Y, c.Forward.Z));
        var up = Vector3.Normalize(new Vector3(c.Up.X, c.Up.Y, c.Up.Z));
        var right = Vector3.Normalize(new Vector3(c.Right.X, c.Right.Y, c.Right.Z));
        // Build look-at view matrix
        var z = -fwd; // camera looks down -Z in view space
        var x = Vector3.Normalize(Vector3.Cross(up, z));
        var y = Vector3.Cross(z, x);
        var view = new Matrix4x4(
            x.X, y.X, z.X, 0,
            x.Y, y.Y, z.Y, 0,
            x.Z, y.Z, z.Z, 0,
            -Vector3.Dot(x, eye), -Vector3.Dot(y, eye), -Vector3.Dot(z, eye), 1);
        return view;
    }

    public static Matrix4x4 Projection(CameraState c)
    {
        float aspect = (float)c.ViewW / Math.Max(1, c.ViewH);
        float fovy = c.FovDegrees * MathF.PI / 180f;
        return Matrix4x4.CreatePerspectiveFieldOfView(fovy, aspect, c.Near, c.Far);
    }

    /// <summary>
    /// Returns screen position (pixels) and whether the point is in front of the camera.
    /// </summary>
    public static (Vector2 screen, bool onScreen, float depth) ToScreen(Vec3 world, CameraState cam)
    {
        var view = View(cam);
        var proj = Projection(cam);
        var p = new Vector3(world.X, world.Y, world.Z);
        var clip = Vector3.Transform(p, view);
        clip = Vector3.Transform(clip, proj);
        if (clip.W <= 0.0001f)
            return (Vector2.Zero, false, clip.Z);
        var ndc = clip / clip.W;
        float sx = (ndc.X * 0.5f + 0.5f) * cam.ViewW;
        float sy = (1f - (ndc.Y * 0.5f + 0.5f)) * cam.ViewH;
        bool onScreen = ndc.Z >= -1 && ndc.Z <= 1 && sx >= 0 && sx <= cam.ViewW && sy >= 0 && sy <= cam.ViewH;
        return (new Vector2(sx, sy), onScreen, ndc.Z);
    }

    public static float Distance(Vec3 a, Vec3 b)
    {
        float dx = a.X - b.X, dy = a.Y - b.Y, dz = a.Z - b.Z;
        return MathF.Sqrt(dx * dx + dy * dy + dz * dz);
    }
}

public static class ColorUtil
{
    public static System.Drawing.Color FromRgb(int rgb)
    {
        int r = (rgb >> 16) & 0xFF;
        int g = (rgb >> 8) & 0xFF;
        int b = rgb & 0xFF;
        return System.Drawing.Color.FromArgb(255, r, g, b);
    }

    public static System.Drawing.Color WithAlpha(System.Drawing.Color c, float a)
    {
        return System.Drawing.Color.FromArgb((int)(Math.Clamp(a, 0, 1) * 255), c.R, c.G, c.B);
    }

    /// <summary>HSV (h in [0,1)) -> RGB color.</summary>
    public static System.Drawing.Color Rainbow(float h)
    {
        h = (h % 1 + 1) % 1;
        float r = 0, g = 0, b = 0;
        int i = (int)(h * 6);
        float f = h * 6 - i;
        float q = 1 - f;
        switch (i % 6)
        {
            case 0: r = 1; g = f; b = 0; break;
            case 1: r = q; g = 1; b = 0; break;
            case 2: r = 0; g = 1; b = f; break;
            case 3: r = 0; g = q; b = 1; break;
            case 4: r = f; g = 0; b = 1; break;
            case 5: r = 1; g = 0; b = q; break;
        }
        return System.Drawing.Color.FromArgb(255, (int)(r * 255), (int)(g * 255), (int)(b * 255));
    }
}
