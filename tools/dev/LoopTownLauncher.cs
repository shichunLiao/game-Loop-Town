using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Windows.Forms;

// Small Windows entry point: resolve all paths before starting the bundled
// engine. This avoids Godot's early user:// log rotation failure on this host.
internal static class LoopTownLauncher
{
    [STAThread]
    private static int Main(string[] args)
    {
        try
        {
            string folder = AppDomain.CurrentDomain.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar);
            string engine = Path.Combine(folder, "LoopTownEngine.exe");
            string pack = Path.Combine(folder, "LoopTownDemo.pck");
            if (!File.Exists(engine) || !File.Exists(pack))
                throw new FileNotFoundException("请保留同一目录中的 LoopTownEngine.exe 和 LoopTownDemo.pck。");
            string logs = Path.Combine(folder, "logs");
            Directory.CreateDirectory(logs);
            string log = Path.Combine(logs, "game-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + ".log");
            var command = new StringBuilder("--main-pack ").Append(Quote(pack))
                .Append(" --path ").Append(Quote(folder)).Append(" --log-file ").Append(Quote(log))
                .Append(" --rendering-method gl_compatibility");
            if (args.Length > 0)
            {
                command.Append(" --");
                foreach (string arg in args) command.Append(" ").Append(Quote(arg));
            }
            var info = new ProcessStartInfo(engine, command.ToString());
            info.WorkingDirectory = folder;
            info.UseShellExecute = false;
            info.CreateNoWindow = true;
            using (Process game = Process.Start(info))
            {
                game.WaitForExit();
                return game.ExitCode;
            }
        }
        catch (Exception error)
        {
            Console.Error.WriteLine(error.ToString());
            try { File.WriteAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"launcher-error.txt"),error.ToString()); } catch { }
            if (args.Length == 0)
                MessageBox.Show("无法启动回环镇。请完整解压游戏包后重试。\n\n" + error.Message, "回环镇", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }

    private static string Quote(string text)
    {
        var result = new StringBuilder("\"");
        int slashes = 0;
        foreach (char c in text)
        {
            if (c == '\\') { slashes++; continue; }
            if (c == '"') result.Append('\\', slashes * 2 + 1).Append(c);
            else result.Append('\\', slashes).Append(c);
            slashes = 0;
        }
        result.Append('\\', slashes * 2).Append('"');
        return result.ToString();
    }
}
