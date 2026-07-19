using System.Runtime.InteropServices;

namespace RobloxEspOverlay;

internal static class Program
{
    [STAThread]
    static void Main()
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        var settings = Settings.Load();

        IEntityProvider provider = settings.Provider switch
        {
            "pipe" => new PipeProvider(settings.PipeName),
            "tcp" => new TcpProvider(settings.TcpHost, settings.TcpPort),
            _ => new DemoProvider(),
        };

        var overlay = new OverlayForm(settings, provider);
        var settingsForm = new SettingsForm(settings, () => { settings.Minimized = !settings.Minimized; settingsForm.SyncFromSettings(); });

        overlay.FormClosed += (_, _) => Cleanup();
        settingsForm.FormClosed += (_, _) => Cleanup();

        bool cleaned = false;
        void Cleanup()
        {
            if (cleaned) return;
            cleaned = true;
            provider.Dispose();
            settings.Save();
            try { overlay?.Dispose(); } catch { }
            try { settingsForm?.Dispose(); } catch { }
            Application.Exit();
        }

        overlay.Show();
        _ = settingsForm.InitAsync();
        settingsForm.Show();

        // Ctrl to toggle minimize (global hotkey) — after handle exists
        RegisterHotKey(overlay.Handle, 1, (uint)MOD.MOD_CONTROL, (uint)VK.VK_CONTROL);

        Application.Run();
    }

    [DllImport("user32.dll")]
    private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    private enum MOD { MOD_CONTROL = 0x0002 }
    private enum VK { VK_CONTROL = 0x11 }
}
