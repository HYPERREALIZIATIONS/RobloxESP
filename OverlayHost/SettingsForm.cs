using Microsoft.Web.WebView2.WinForms;

namespace RobloxEspOverlay;

/// <summary>
/// A borderless settings window hosting the React UI via WebView2.
/// Communicates with the React app through window.chrome.webview.postMessage.
/// </summary>
public class SettingsForm : Form
{
    private readonly WebView2 _web;
    private readonly Settings _settings;

    public SettingsForm(Settings settings, Action onMinimizeHotkey)
    {
        _settings = settings;
        _ = onMinimizeHotkey;

        FormBorderStyle = FormBorderStyle.None;
        TopMost = true;
        Width = 300; Height = 620;
        Location = new Point(40, 40);
        BackColor = Color.FromArgb(18, 18, 24);

        _web = new WebView2 { Dock = DockStyle.Fill };
        Controls.Add(_web);
        _web.NavigationCompleted += async (_, __) =>
        {
            // Push current settings into the page
            await _web.ExecuteScriptAsync("window.__applySettings(" + System.Text.Json.JsonSerializer.Serialize(_settings) + ");");
        };
        _web.WebMessageReceived += (_, e) =>
        {
            var msg = e.TryGetWebMessageAsString();
            if (msg == null) return;
            ApplyMessage(msg);
        };
    }

    public async Task InitAsync()
    {
        // Use bundled files via a virtual host; simpler: load from disk.
        var uiDir = System.IO.Path.Combine(System.AppContext.BaseDirectory, "ReactUi", "dist");
        await _web.EnsureCoreWebView2Async();
        // Map a virtual host so relative assets work
        _web.CoreWebView2.SetVirtualHostNameToFolderMapping(
            "app.local", uiDir, Microsoft.Web.WebView2.Core.CoreWebView2HostResourceAccessKind.Allow);
        _web.Source = new Uri("https://app.local/index.html");
    }

    private void ApplyMessage(string json)
    {
        try
        {
            var patch = System.Text.Json.JsonSerializer.Deserialize<Dictionary<string, object>>(json);
            if (patch == null) return;
            foreach (var kv in patch)
            {
                var prop = typeof(Settings).GetProperty(kv.Key);
                if (prop == null || kv.Value == null) continue;
                var t = prop.PropertyType;
                object? val = kv.Value switch
                {
                    JsonElement je when t == typeof(int) => je.GetInt32(),
                    JsonElement je when t == typeof(float) => (float)je.GetDouble(),
                    JsonElement je when t == typeof(bool) => je.GetBoolean(),
                    JsonElement je when t == typeof(string) => je.GetString(),
                    _ => null
                };
                if (val != null) prop.SetValue(_settings, val);
            }
            _settings.Save();
        }
        catch { }
    }

    public void SyncFromSettings()
    {
        try
        {
            _web.ExecuteScriptAsync("window.__applySettings(" + System.Text.Json.JsonSerializer.Serialize(_settings) + ");");
        }
        catch { }
    }
}
