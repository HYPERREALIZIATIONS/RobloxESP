using System.Drawing;
using System.Drawing.Drawing2D;

namespace RobloxEspOverlay;

/// <summary>
/// Draws ESP for a frame using GDI+ onto the overlay form's Graphics context.
/// The overlay form is transparent and sits on top of the Roblox window.
/// </summary>
public class Renderer
{
    private float _rainbowHue = 0f;

    public void Render(Graphics g, Frame frame, Settings s, Point tracerMouse)
    {
        if (!s.Enabled || s.Minimized) return;

        if (s.Rainbow)
            _rainbowHue = (_rainbowHue + 0.016f * s.RainbowSpeed) % 1f;

        var cam = frame.Camera;
        foreach (var e in frame.Entities)
        {
            try { DrawEntity(g, e, cam, s, tracerMouse); }
            catch { /* skip bad entity */ }
        }
    }

    private void DrawEntity(Graphics g, Entity e, CameraState cam, Settings s, Point mouse)
    {
        // Team check
        if (s.TeamCheck && e.IsTeammate) return;

        // Distance cull
        float dist = Project.Distance(e.Root, cam.Position);
        if (s.DistanceLimit > 0 && dist > s.DistanceLimit) return;

        var boxColor = s.Rainbow ? ColorUtil.Rainbow(_rainbowHue) : ColorUtil.FromRgb(s.BoxColor);
        var skelColor = s.Rainbow ? ColorUtil.Rainbow(_rainbowHue) : ColorUtil.FromRgb(s.SkeletonColor);
        var tracerColor = s.Rainbow ? ColorUtil.Rainbow(_rainbowHue) : ColorUtil.FromRgb(s.TracerColor);
        var nameColor = ColorUtil.FromRgb(s.NameColor);

        // Project key points
        var (rootS, rootOn) = Project.ToScreen(e.Root, cam);
        var (headS, headOn) = Project.ToScreen(e.Head, cam);
        var (feetS, feetOn) = Project.ToScreen(e.Feet, cam);
        if (!rootOn && !headOn) return;

        // Derive box rectangle from head/feet screen positions
        float topY = headOn ? headS.Y - 6 : Math.Min(rootS.Y, feetS.Y) - 60;
        float botY = feetOn ? feetS.Y : Math.Max(rootS.Y, headS.Y) + 60;
        float cx = (headOn ? headS.X : rootS.X);
        float boxH = Math.Abs(botY - topY);
        float boxW = Math.Max(boxH * 0.45f, 16f);
        float left = cx - boxW / 2;
        float right = cx + boxW / 2;

        Color oc = ColorUtil.WithAlpha(boxColor, s.BoxOpacity);

        // ---- Box ----
        if (s.BoxMode == "full")
        {
            using var pen = new Pen(oc, s.BoxThickness);
            g.DrawRectangle(pen, left, topY, boxW, boxH);
        }
        else if (s.BoxMode == "corner")
        {
            DrawCorners(g, left, right, topY, botY, oc, s.BoxThickness);
        }
        else if (s.BoxMode == "threed")
        {
            Draw3DBox(g, e, cam, oc, s.BoxThickness);
        }

        // ---- Skeleton ----
        if (s.Skeleton && !s.PerformanceMode)
        {
            DrawSkeleton(g, e, cam, ColorUtil.WithAlpha(skelColor, 1f), s.SkeletonThickness);
        }

        // ---- Chams (outline emulation: glow under box) ----
        if (s.Chams)
        {
            using var pen = new Pen(ColorUtil.WithAlpha(ColorUtil.FromRgb(s.ChamsColor), s.ChamsOpacity), s.BoxThickness + 4);
            g.DrawRectangle(pen, left - 3, topY - 3, boxW + 6, boxH + 6);
        }

        // ---- Health bar ----
        if (s.HealthBar)
        {
            float ratio = Math.Clamp(e.Health / Math.Max(1f, e.MaxHealth), 0, 1);
            float bw = 3;
            float bx = left - 7;
            var hc = ratio > 0.5f ? ColorUtil.FromRgb(s.HealthColor) : ColorUtil.FromRgb(s.HealthColorBad);
            using (var bg = new SolidBrush(Color.FromArgb(120, 0, 0, 0)))
                g.FillRectangle(bg, bx, topY, bw, boxH);
            using (var fg = new SolidBrush(hc))
                g.FillRectangle(fg, bx, botY - boxH * ratio, bw, boxH * ratio);
        }

        // ---- Tracer ----
        if (s.Tracer)
        {
            Point origin = s.TracerOrigin switch
            {
                "center" => new Point(cam.ViewW / 2, cam.ViewH / 2),
                "mouse" => mouse,
                _ => new Point(cam.ViewW / 2, cam.ViewH),
            };
            using var pen = new Pen(ColorUtil.WithAlpha(tracerColor, 1f), s.TracerThickness);
            g.DrawLine(pen, origin, new Point((int)cx, (int)botY));
        }

        // ---- Name ----
        if (s.Names)
        {
            using var font = new Font("Segoe UI", s.NameSize, FontStyle.Bold);
            using var brush = new SolidBrush(nameColor);
            string txt = $"{e.Name} [{Math.Round(dist)}m]";
            var sf = new StringFormat { Alignment = StringAlignment.Center };
            g.DrawString(txt, font, brush, cx, topY - s.NameSize - 6, sf);
        }
    }

    private void DrawCorners(Graphics g, float l, float r, float t, float b, Color c, float thick)
    {
        float len = 10;
        using var pen = new Pen(c, thick);
        // TL
        g.DrawLine(pen, l, t, l + len, t); g.DrawLine(pen, l, t, l, t + len);
        // TR
        g.DrawLine(pen, r, t, r - len, t); g.DrawLine(pen, r, t, r, t + len);
        // BL
        g.DrawLine(pen, l, b, l + len, b); g.DrawLine(pen, l, b, l, b - len);
        // BR
        g.DrawLine(pen, r, b, r - len, b); g.DrawLine(pen, r, b, r, b - len);
    }

    private void Draw3DBox(Graphics g, Entity e, CameraState cam, Color c, float thick)
    {
        // Build a box around root using width/height (studs)
        float hw = e.Width * 0.5f, hh = e.Height * 0.5f, hd = e.Width * 0.5f;
        Vec3 c0 = e.Root;
        var corners = new Vec3[]
        {
            new(c0.X - hw, c0.Y + hh, c0.Z - hd), new(c0.X + hw, c0.Y + hh, c0.Z - hd),
            new(c0.X + hw, c0.Y + hh, c0.Z + hd), new(c0.X - hw, c0.Y + hh, c0.Z + hd),
            new(c0.X - hw, c0.Y - hh, c0.Z - hd), new(c0.X + hw, c0.Y - hh, c0.Z - hd),
            new(c0.X + hw, c0.Y - hh, c0.Z + hd), new(c0.X - hw, c0.Y - hh, c0.Z + hd),
        };
        var pts = new Point[8];
        bool allOn = true;
        for (int i = 0; i < 8; i++)
        {
            var (sp, on) = Project.ToScreen(corners[i], cam);
            pts[i] = new Point((int)sp.X, (int)sp.Y);
            if (!on) allOn = false;
        }
        if (!allOn) return;
        int[][] edges = {
            new[]{0,1},new[]{1,2},new[]{2,3},new[]{3,0},
            new[]{4,5},new[]{5,6},new[]{6,7},new[]{7,4},
            new[]{0,4},new[]{1,5},new[]{2,6},new[]{3,7},
        };
        using var pen = new Pen(c, thick);
        foreach (var ed in edges)
            g.DrawLine(pen, pts[ed[0]], pts[ed[1]]);
    }

    private void DrawSkeleton(Graphics g, Entity e, CameraState cam, Color c, float thick)
    {
        List<Bone> bones = e.Bones;
        if (bones.Count == 0)
        {
            // derive simple biped skeleton
            Vec3 hip = e.Root;
            Vec3 chest = new(e.Root.X, e.Root.Y + e.Height * 0.45f, e.Root.Z);
            Vec3 head = e.Head;
            bones = new List<Bone>
            {
                new() { A = hip, B = chest },
                new() { A = chest, B = head },
                new() { A = chest, B = new(chest.X - e.Width*0.6f, chest.Y, chest.Z) },
                new() { A = chest, B = new(chest.X + e.Width*0.6f, chest.Y, chest.Z) },
                new() { A = hip, B = new(hip.X - e.Width*0.5f, hip.Y - e.Height*0.5f, hip.Z) },
                new() { A = hip, B = new(hip.X + e.Width*0.5f, hip.Y - e.Height*0.5f, hip.Z) },
            };
        }
        using var pen = new Pen(c, thick);
        foreach (var bn in bones)
        {
            var (a, onA) = Project.ToScreen(bn.A, cam);
            var (b, onB) = Project.ToScreen(bn.B, cam);
            if (onA && onB) g.DrawLine(pen, a.X, a.Y, b.X, b.Y);
        }
    }
}
