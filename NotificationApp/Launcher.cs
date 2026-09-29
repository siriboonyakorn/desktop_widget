using System;
using System.Diagnostics;
using System.IO;
internal static class Launcher {
    [STAThread]
    private static void Main() {
        string rootFile = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "WidgetRoot.txt");
        string root = File.Exists(rootFile) ? File.ReadAllText(rootFile).Trim() : Directory.GetParent(AppDomain.CurrentDomain.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar)).FullName;
        var start = new ProcessStartInfo("powershell.exe",
            "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File \"" + Path.Combine(root, "ClockWidget.ps1") + "\"");
        start.UseShellExecute = false;
        start.CreateNoWindow = true;
        start.WorkingDirectory = root;
        Process.Start(start);
    }
}
