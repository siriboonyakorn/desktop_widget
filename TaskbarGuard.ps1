param([int]$ParentId, [string]$Token)
$ErrorActionPreference = 'Stop'
Add-Type @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class TaskbarGuardNative {
    private delegate bool EnumProc(IntPtr h, IntPtr p);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumProc proc, IntPtr p);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr h, StringBuilder text, int size);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] private static extern bool ShowWindow(IntPtr h, int command);
    private static HashSet<IntPtr> hidden = new HashSet<IntPtr>();
    public static void Hide() {
        EnumWindows(delegate(IntPtr h, IntPtr p) {
            var text = new StringBuilder(256); GetClassName(h,text,256);
            if ((text.ToString()=="Shell_TrayWnd" || text.ToString()=="Shell_SecondaryTrayWnd") && IsWindowVisible(h)) {
                hidden.Add(h); ShowWindow(h,0);
            }
            return true;
        },IntPtr.Zero);
    }
    public static void Restore() {
        foreach (var h in hidden) {
            var text = new StringBuilder(256); GetClassName(h,text,256);
            if (text.ToString()=="Shell_TrayWnd" || text.ToString()=="Shell_SecondaryTrayWnd") ShowWindow(h,5);
        }
    }
}
'@
try {
    $owner = Get-Process -Id $ParentId -ErrorAction Stop
    while (-not $owner.HasExited -and (Test-Path -LiteralPath $Token)) {
        [TaskbarGuardNative]::Hide()
        Start-Sleep -Milliseconds 500
        $owner.Refresh()
    }
} finally {
    [TaskbarGuardNative]::Restore()
    if (Test-Path -LiteralPath $Token) { Remove-Item -LiteralPath $Token -ErrorAction SilentlyContinue }
}
