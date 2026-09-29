using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Windows.Automation;
public static class WidgetTray {
    public sealed class Item {
        public string Name, Path;
        public bool RegisteredApp;
        internal AutomationElement Element;
        public Task OpenAsync() { return Task.Run(() => {
            if(Element==null) {
                foreach(var process in System.Diagnostics.Process.GetProcesses()) {
                    using(process) {try {
                        if(process.MainWindowHandle!=IntPtr.Zero && String.Equals(process.MainModule.FileName,Path,StringComparison.OrdinalIgnoreCase)) {
                            ShowWindowAsync(process.MainWindowHandle,9); SetForegroundWindow(process.MainWindowHandle); return;
                        }
                    } catch {} }
                }
                System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(Path) {UseShellExecute=true}); return; }
            object pattern;
            if (Element.TryGetCurrentPattern(InvokePattern.Pattern, out pattern)) ((InvokePattern)pattern).Invoke();
            else throw new InvalidOperationException("This icon requires the Windows tray menu.");
        }); }
    }
    [DllImport("user32.dll")] static extern bool ShowWindowAsync(IntPtr window,int command);
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr window);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern IntPtr FindWindow(string cls,string name);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern IntPtr FindWindowEx(IntPtr parent,IntPtr after,string cls,string name);
    [DllImport("shell32.dll")] static extern int SHGetKnownFolderPath(ref Guid id,uint flags,IntPtr token,out IntPtr path);
    static string ResolvePath(string path) {
        if(path.StartsWith("{")) {
            int end=path.IndexOf('}'); Guid id; IntPtr folder;
            if(end>0 && Guid.TryParse(path.Substring(0,end+1),out id) && SHGetKnownFolderPath(ref id,0,IntPtr.Zero,out folder)==0) {
                try {path=Marshal.PtrToStringUni(folder)+path.Substring(end+1);} finally {Marshal.FreeCoTaskMem(folder);}
            }
        }
        return Environment.ExpandEnvironmentVariables(path);
    }
    public static Task<Item[]> ReadAsync() { return Task.Run(() => {
        var result = new List<Item>(); var seen = new HashSet<string>();
        var taskbar = FindWindow("Shell_TrayWnd",null);
        var roots = new [] { FindWindowEx(taskbar,IntPtr.Zero,"TrayNotifyWnd",null), FindWindow("NotifyIconOverflowWindow",null), FindWindow("TopLevelWindowForOverflowXamlIsland",null) };
        foreach(var handle in roots) {
            if(handle == IntPtr.Zero) continue;
            try {
                var root = AutomationElement.FromHandle(handle);
                var buttons = root.FindAll(TreeScope.Descendants,new PropertyCondition(AutomationElement.ControlTypeProperty,ControlType.Button));
                foreach(AutomationElement element in buttons) {
                    try {
                        var name = element.Current.Name;
                        if(String.IsNullOrWhiteSpace(name) || !element.Current.IsEnabled || !seen.Add(name)) continue;
                        // The overflow chevron is navigation, not an application.
                        var id = element.Current.AutomationId;
                        if(id == "SystemTrayIcon" || name == "Show hidden icons") continue;
                        result.Add(new Item {Name=name, Element=element});
                    } catch(ElementNotAvailableException) {}
                }
            } catch(ElementNotAvailableException) {}
        }
        // Windows 11 may hide its accessibility tree with the taskbar. Supplement
        // it with registered notification apps whose exact executable is running.
        var running=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach(var process in System.Diagnostics.Process.GetProcesses()) {
            using(process) {try {running.Add(process.MainModule.FileName);} catch {} }
        }
        using(var key=Microsoft.Win32.Registry.CurrentUser.OpenSubKey(@"Control Panel\NotifyIconSettings")) {
            if(key!=null) foreach(var child in key.GetSubKeyNames()) {
                using(var entry=key.OpenSubKey(child)) {
                    string path=ResolvePath(Convert.ToString(entry.GetValue("ExecutablePath","")));
                    if(!running.Contains(path) || !seen.Add(path))continue;
                    string name=Convert.ToString(entry.GetValue("InitialTooltip",""));
                    if(String.IsNullOrWhiteSpace(name))name=System.IO.Path.GetFileNameWithoutExtension(path);
                    if(!seen.Add(name))continue;
                    result.Add(new Item{Name=name,Path=path,RegisteredApp=true});
                }
            }
        }
        return result.ToArray();
    }); }
}
