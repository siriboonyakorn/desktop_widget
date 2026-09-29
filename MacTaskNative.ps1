Add-Type @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
public static class MacTaskNative {
    public class Task { public IntPtr Handle; public string Title; public string Path; public string Name; }
    private delegate bool EnumProc(IntPtr h, IntPtr p);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumProc cb, IntPtr p);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] private static extern IntPtr GetWindow(IntPtr h, uint cmd);
    [DllImport("user32.dll")] private static extern int GetWindowLong(IntPtr h, int index);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetWindowText(IntPtr h, StringBuilder s, int count);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("dwmapi.dll")] private static extern int DwmGetWindowAttribute(IntPtr h, int attribute, out int value, int size);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
    [StructLayout(LayoutKind.Sequential)] private struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] private struct Monitor { public int Size; public Rect Bounds, Work; public uint Flags; }
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr h, out Rect r);
    [DllImport("user32.dll")] private static extern IntPtr MonitorFromWindow(IntPtr h, uint flags);
    [DllImport("user32.dll")] private static extern bool GetMonitorInfo(IntPtr h, ref Monitor m);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr h, StringBuilder s, int count);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern IntPtr FindWindow(string cls, string name);
    [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] private static extern void keybd_event(byte key, byte scan, uint flags, UIntPtr extra);
    public static void ShowTray() {
        var h=FindWindow("Shell_TrayWnd",null); if(h!=IntPtr.Zero) ShowWindowAsync(h,5);
        keybd_event(0x5B,0,0,UIntPtr.Zero); keybd_event(0x42,0,0,UIntPtr.Zero);
        keybd_event(0x42,0,2,UIntPtr.Zero); keybd_event(0x5B,0,2,UIntPtr.Zero);
    }
    public static bool IsTrayActive() {
        var cls=new StringBuilder(256); GetClassName(GetForegroundWindow(),cls,256);
        string name=cls.ToString();
        return name=="Shell_TrayWnd" || name=="Shell_SecondaryTrayWnd" || name=="NotifyIconOverflowWindow" || name=="TopLevelWindowForOverflowXamlIsland" || name=="#32768" || name=="XamlExplorerHostIslandWindow";
    }
    public static bool IsFullscreen(IntPtr h) {
        if ((GetWindowLong(h,-16) & 0x00C00000) == 0x00C00000) return false;
        var cls = new StringBuilder(256); GetClassName(h,cls,256);
        if (cls.ToString()=="Progman" || cls.ToString()=="WorkerW" || cls.ToString()=="Shell_TrayWnd") return false;
        Rect r; var m = new Monitor(); m.Size = Marshal.SizeOf(m);
        if (!GetWindowRect(h,out r) || !GetMonitorInfo(MonitorFromWindow(h,2),ref m)) return false;
        return r.Left <= m.Bounds.Left && r.Top <= m.Bounds.Top && r.Right >= m.Bounds.Right && r.Bottom >= m.Bounds.Bottom;
    }
    public static void Activate(IntPtr h) { if (IsIconic(h)) ShowWindowAsync(h,9); SetForegroundWindow(h); }
    public static Task[] Tasks() {
        var list = new List<Task>(); int self = Process.GetCurrentProcess().Id;
        EnumWindows(delegate(IntPtr h, IntPtr p) {
            if (!IsWindowVisible(h) || GetWindow(h,4)!=IntPtr.Zero || (GetWindowLong(h,-20)&0x80)!=0) return true;
            int cloaked; if (DwmGetWindowAttribute(h,14,out cloaked,4)==0 && cloaked!=0) return true;
            var title = new StringBuilder(512); GetWindowText(h,title,512); if (title.Length==0) return true;
            uint id; GetWindowThreadProcessId(h,out id); if (id==self) return true;
            try { using (var proc = Process.GetProcessById((int)id)) {
                string path = ""; try { path=proc.MainModule.FileName; } catch { }
                list.Add(new Task { Handle=h, Title=title.ToString(), Path=path, Name=proc.ProcessName });
            } } catch { }
            return true;
        },IntPtr.Zero);
        return list.ToArray();
    }
}
'@
