using System.Runtime.InteropServices;

namespace RobloxEspOverlay;

/// <summary>
/// Transparent, click-through, topmost overlay window that tracks the Roblox
/// client window. Draws ESP each frame via Renderer.
/// </summary>
public class OverlayForm : Form
{
    private readonly Settings _settings;
    private readonly IEntityProvider _provider;
    private readonly Renderer _renderer = new();
    private System.Windows.Forms.Timer _timer = new() { Interval = 16 };
    private IntPtr _targetHwnd = IntPtr.Zero;
    private Point _mouse = Point.Empty;

    public OverlayForm(Settings settings, IEntityProvider provider)
    {
        _settings = settings;
        _provider = provider;

        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        TopMost = true;
        TransparencyKey = Color.Magenta;
        BackColor = Color.Magenta;
        Opacity = 1;
        Dock = DockStyle.None;
        Width = Screen.PrimaryScreen?.Bounds.Width ?? 1920;
        Height = Screen.PrimaryScreen?.Bounds.Height ?? 1080;
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.DoubleBuffer, true);

        _timer.Tick += Tick;
        _timer.Start();
    }

    private void Tick(object? sender, EventArgs e)
    {
        // Find / follow Roblox window
        if (_targetHwnd == IntPtr.Zero || !IsWindowVisible(_targetHwnd))
            _targetHwnd = FindRobloxWindow();

        if (_targetHwnd != IntPtr.Zero)
        {
            var rect = GetWindowRect(_targetHwnd);
            Bounds = rect;
        }

        GetCursorPos(out var mp);
        _mouse = new Point(mp.X, mp.Y);

        Invalidate();
    }

    /// <summary>Toggle overlay hidden state (Ctrl hotkey).</summary>
    public void ToggleMinimize()
    {
        _settings.Minimized = !_settings.Minimized;
        Visible = !_settings.Minimized;
    }

    protected override void WndProc(ref Message m)
    {
        const int WM_HOTKEY = 0x0312;
        if (m.Msg == WM_HOTKEY && m.WParam.ToInt32() == 1)
        {
            ToggleMinimize();
            return;
        }
        base.WndProc(ref m);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        var frame = _provider.GetFrame();
        if (frame != null)
        {
            e.Graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
            _renderer.Render(e.Graphics, frame, _settings, _mouse);
        }
    }

    // ---- Win32 helpers ----
    private static IntPtr FindRobloxWindow()
    {
        IntPtr found = IntPtr.Zero;
        EnumWindows((hwnd, _) =>
        {
            if (!IsWindowVisible(hwnd)) return true;
            int len = GetWindowTextLength(hwnd);
            if (len == 0) return true;
            var sb = new System.Text.StringBuilder(len + 1);
            GetWindowText(hwnd, sb, len + 1);
            string title = sb.ToString();
            if (title.Contains("Roblox") || title.Contains("Roblox Player"))
            {
                found = hwnd;
                return false; // stop
            }
            return true;
        }, IntPtr.Zero);
        return found;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)]
    private struct POINT { public int X, Y; }

    private static Rectangle GetWindowRect(IntPtr hwnd)
    {
        RECT r = new();
        GetWindowRect(hwnd, ref r);
        return Rectangle.FromLTRB(r.Left, r.Top, r.Right, r.Bottom);
    }

    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumWindowsProc lp, IntPtr lParam);
    [DllImport("user32.dll")] private static extern int GetWindowTextLength(IntPtr h);
    [DllImport("user32.dll")] private static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr h, ref RECT r);
    [DllImport("user32.dll")] private static extern bool GetCursorPos(out POINT p);
    private delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr lParam);
}
