namespace RobloxEspOverlay;

/// <summary>
/// Supplies entity frames to the overlay. Implementations decide the source.
/// NOTE: This tool does NOT scan Roblox process memory. Authorized use only
/// (your own experience, or a friend's experience with their permission / for
/// anti-cheat testing). Provide data through a consented channel.
/// </summary>
public interface IEntityProvider : IDisposable
{
    /// <summary>Returns the latest frame, or null if none yet.</summary>
    Frame? GetFrame();

    /// <summary>True once the provider is connected/ready.</summary>
    bool IsReady { get; }
}

/// <summary>
/// Demo provider: generates moving mock entities so you can tune the visuals
/// immediately without any game connection.
/// </summary>
public class DemoProvider : IEntityProvider
{
    private DateTime _start = DateTime.UtcNow;
    public bool IsReady => true;

    public Frame? GetFrame()
    {
        float t = (float)(DateTime.UtcNow - _start).TotalSeconds;
        var cam = new CameraState
        {
            Position = new Vec3(0, 6, -24),
            Forward = new Vec3(0, 0, 1),
            Up = new Vec3(0, 1, 0),
            Right = new Vec3(1, 0, 0),
            FovDegrees = 70,
            ViewW = 1920,
            ViewH = 1080,
        };
        var ents = new List<Entity>();
        int count = 6;
        for (int i = 0; i < count; i++)
        {
            float ang = t * 0.4f + i * (MathF.PI * 2 / count);
            float rad = 10 + 3 * MathF.Sin(t * 0.7f + i);
            float x = MathF.Cos(ang) * rad;
            float z = MathF.Sin(ang) * rad + 6;
            float y = 3 + MathF.Sin(t + i) * 1.5f;
            ents.Add(new Entity
            {
                Name = "Player_" + (i + 1),
                Team = (i % 2 == 0) ? "Blue" : "Red",
                IsTeammate = (i % 2 == 0),
                Health = 40 + 60 * (0.5f + 0.5f * MathF.Sin(t + i)),
                MaxHealth = 100,
                Rig = (i % 3 == 0) ? RigKind.R6 : RigKind.R15,
                Root = new Vec3(x, y, z),
                Head = new Vec3(x, y + 2.2f, z),
                Feet = new Vec3(x, 0, z),
                Height = 5,
                Width = 2,
            });
        }
        return new Frame { Camera = cam, Entities = ents };
    }

    public void Dispose() { }
}

/// <summary>
/// Reads entity frames from a local named pipe. The game (or a consented
/// test harness) writes JSON Frame objects. Recommended for authorized testing.
/// Protocol: each message is a UTF-8 JSON Frame followed by a newline.
/// </summary>
public class PipeProvider : IEntityProvider
{
    private readonly string _pipeName;
    private System.IO.Pipes.NamedPipeClientStream? _pipe;
    private StreamReader? _reader;
    private Frame? _last;
    private Thread _thread;
    private volatile bool _running = true;

    public PipeProvider(string pipeName) { _pipeName = pipeName; _thread = new Thread(Loop) { IsBackground = true }; _thread.Start(); }

    public bool IsReady { get; private set; }

    private void Loop()
    {
        while (_running)
        {
            try
            {
                _pipe = new System.IO.Pipes.NamedPipeClientStream(".", _pipeName, System.IO.Pipes.PipeDirection.In);
                _pipe.Connect(500);
                _reader = new StreamReader(_pipe);
                IsReady = true;
                string? line;
                while (_running && (line = _reader.ReadLine()) != null)
                {
                    if (line.Length == 0) continue;
                    var f = System.Text.Json.JsonSerializer.Deserialize<Frame>(line);
                    if (f != null) _last = f;
                }
            }
            catch
            {
                IsReady = false;
                Thread.Sleep(1000); // retry
            }
            finally
            {
                try { _reader?.Dispose(); _pipe?.Dispose(); } catch { }
                _reader = null; _pipe = null;
            }
        }
    }

    public Frame? GetFrame() => _last;

    public void Dispose()
    {
        _running = false;
        try { _pipe?.Dispose(); } catch { }
    }
}

/// <summary>
/// Reads entity frames from a TCP localhost socket. Same JSON-line protocol.
/// </summary>
public class TcpProvider : IEntityProvider
{
    private readonly string _host;
    private readonly int _port;
    private TcpClient? _client;
    private StreamReader? _reader;
    private Frame? _last;
    private Thread _thread;
    private volatile bool _running = true;

    public TcpProvider(string host, int port) { _host = host; _port = port; _thread = new Thread(Loop) { IsBackground = true }; _thread.Start(); }

    public bool IsReady { get; private set; }

    private void Loop()
    {
        while (_running)
        {
            try
            {
                _client = new TcpClient();
                _client.Connect(_host, _port);
                _reader = new StreamReader(_client.GetStream());
                IsReady = true;
                string? line;
                while (_running && (line = _reader.ReadLine()) != null)
                {
                    if (line.Length == 0) continue;
                    var f = System.Text.Json.JsonSerializer.Deserialize<Frame>(line);
                    if (f != null) _last = f;
                }
            }
            catch
            {
                IsReady = false;
                Thread.Sleep(1000);
            }
            finally
            {
                try { _reader?.Dispose(); _client?.Dispose(); } catch { }
                _reader = null; _client = null;
            }
        }
    }

    public Frame? GetFrame() => _last;

    public void Dispose()
    {
        _running = false;
        try { _client?.Dispose(); } catch { }
    }
}
