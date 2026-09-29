# Lightweight native counters; no performance-counter service or admin access.
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class WidgetSystem {
    [StructLayout(LayoutKind.Sequential)] public struct Memory {
        public uint Length, Load;
        public ulong TotalPhysical, AvailablePhysical, TotalPageFile, AvailablePageFile, TotalVirtual, AvailableVirtual, AvailableExtended;
    }
    public struct Cpu { public ulong Idle, Kernel, User; }
    [DllImport("kernel32.dll")] static extern bool GetSystemTimes(out ulong idle, out ulong kernel, out ulong user);
    [DllImport("kernel32.dll")] static extern bool GlobalMemoryStatusEx(ref Memory memory);
    public static Cpu ReadCpu() {
        Cpu value = new Cpu();
        if (!GetSystemTimes(out value.Idle, out value.Kernel, out value.User)) throw new InvalidOperationException("CPU unavailable");
        return value;
    }
    public static Memory ReadMemory() {
        Memory value = new Memory(); value.Length = (uint)Marshal.SizeOf(typeof(Memory));
        if (!GlobalMemoryStatusEx(ref value)) throw new InvalidOperationException("Memory unavailable");
        return value;
    }
}
'@
[xml]$monitorXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 Title="System monitor widget" Width="298" Height="132" WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True"
 Background="Transparent" ShowInTaskbar="False" ShowActivated="False" Opacity="0" FontFamily="Segoe UI" Foreground="White">
 <Grid Margin="4,24,4,4">
  <Grid.RenderTransform><TranslateTransform x:Name="MonitorSlide" Y="-20"/></Grid.RenderTransform>
  <Border x:Name="MonitorGlass" CornerRadius="19" BorderThickness="1" Padding="14,11">
   <StackPanel>
    <TextBlock Text="SYSTEM" FontSize="10" FontWeight="SemiBold" Foreground="#C7D9ED" Margin="0,0,0,7"/>
    <UniformGrid x:Name="MonitorMetrics" Rows="1" Columns="3"/>
   </StackPanel>
  </Border>
  <Border Margin="2" CornerRadius="17" BorderBrush="#28FFFFFF" BorderThickness="0.7" IsHitTestVisible="False"/>
 </Grid>
</Window>
'@
$script:monitorWindow = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($monitorXaml))
$monitorWindow.FindName('MonitorGlass').Background = $glassSource.Background.Clone()
$monitorWindow.FindName('MonitorGlass').BorderBrush = $glassSource.BorderBrush.Clone()
$script:cornerCards += @{ Name = 'SystemMonitor'; Window = $monitorWindow; Slide = $monitorWindow.FindName('MonitorSlide'); Handle = [IntPtr]::Zero; Visible = $false; LastNear = [DateTime]::MinValue; Anchor = 'TopCenter' }
$script:monitorMetrics = @{}
foreach ($name in @('CPU','RAM','DISK')) {
    $panel = [Windows.Controls.StackPanel]::new()
    $panel.Margin = [Windows.Thickness]::new(0,0,8,0)
    $heading = [Windows.Controls.TextBlock]::new(); $heading.Text = $name; $heading.FontSize = 9; $heading.Opacity = 0.7
    $value = [Windows.Controls.TextBlock]::new(); $value.Text = '--'; $value.FontSize = 20; $value.FontWeight = 'Light'
    $track = [Windows.Controls.Border]::new(); $track.Width = 70; $track.Height = 3; $track.HorizontalAlignment = 'Left'
    $track.Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#25FFFFFF'); $track.CornerRadius = [Windows.CornerRadius]::new(1.5)
    $bar = [Windows.Controls.Border]::new(); $bar.Width = 0; $bar.HorizontalAlignment = 'Left'; $bar.CornerRadius = [Windows.CornerRadius]::new(1.5)
    $bar.Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#BCE2F5'); $track.Child = $bar
    [void]$panel.Children.Add($heading); [void]$panel.Children.Add($value); [void]$panel.Children.Add($track)
    [void]$monitorWindow.FindName('MonitorMetrics').Children.Add($panel)
    $script:monitorMetrics[$name] = @{ Value = $value; Bar = $bar; Panel = $panel }
}
$script:monitorPreviousCpu = $null
$script:monitorNextPoll = [DateTime]::MinValue
$script:monitorNextDisk = [DateTime]::MinValue

function Get-WidgetCpuPercent($Before, $After) {
    if ($null -eq $Before) { return $null }
    $kernel = [double]$After.Kernel - [double]$Before.Kernel
    $user = [double]$After.User - [double]$Before.User
    $idle = [double]$After.Idle - [double]$Before.Idle
    $total = $kernel + $user
    if ($total -le 0 -or $idle -lt 0 -or $kernel -lt 0 -or $user -lt 0) { return $null }
    return [Math]::Max(0.0, [Math]::Min(100.0, 100.0 * ($total - $idle) / $total))
}

function Set-MonitorMetric([string]$Name, $Percent, [string]$Detail) {
    $metric = $script:monitorMetrics[$Name]
    $metric.Value.Text = if ($null -eq $Percent) { '--' } else { '{0:0}%' -f $Percent }
    $metric.Bar.Width = if ($null -eq $Percent) { 0 } else { 70 * [Math]::Max(0.0,[Math]::Min(100.0,$Percent)) / 100 }
    $metric.Panel.ToolTip = $Detail
}

function Update-SystemMonitor {
    if ([DateTime]::UtcNow -lt $script:monitorNextPoll) { return }
    $script:monitorNextPoll = [DateTime]::UtcNow.AddSeconds(2)
    try {
        $cpu = [WidgetSystem]::ReadCpu()
        $percent = Get-WidgetCpuPercent $script:monitorPreviousCpu $cpu
        $script:monitorPreviousCpu = $cpu
        Set-MonitorMetric 'CPU' $percent 'Total CPU usage, sampled every two seconds'
    } catch { $script:monitorPreviousCpu = $null; Set-MonitorMetric 'CPU' $null 'CPU reading unavailable' }
    try {
        $memory = [WidgetSystem]::ReadMemory()
        $used = [double]$memory.TotalPhysical - [double]$memory.AvailablePhysical
        Set-MonitorMetric 'RAM' (100 * $used / $memory.TotalPhysical) ('{0:0.0} / {1:0.0} GB in use' -f ($used / 1GB), ($memory.TotalPhysical / 1GB))
    } catch { Set-MonitorMetric 'RAM' $null 'Memory reading unavailable' }
    if ([DateTime]::UtcNow -ge $script:monitorNextDisk) {
        $script:monitorNextDisk = [DateTime]::UtcNow.AddSeconds(30)
        try {
            $drive = [IO.DriveInfo]::new([IO.Path]::GetPathRoot($env:WINDIR))
            if (-not $drive.IsReady -or $drive.TotalSize -le 0) { throw 'System drive unavailable' }
            Set-MonitorMetric 'DISK' (100 * (1 - $drive.TotalFreeSpace / [double]$drive.TotalSize)) ('{0}  {1:0.0} GB free / {2:0.0} GB total' -f $drive.Name, ($drive.TotalFreeSpace / 1GB), ($drive.TotalSize / 1GB))
        } catch { Set-MonitorMetric 'DISK' $null 'System-drive storage reading unavailable' }
    }
}
