# Five real Windows shortcuts, sharing the corner cards' hover and lifecycle.
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class DockNative {
    [StructLayout(LayoutKind.Sequential)] public struct Size { public int Width; public int Height; }
    [ComImport, Guid("bcc18b79-ba16-442f-80c4-8a59c30c463b"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface ImageFactory { [PreserveSig] int GetImage(Size size, uint flags, out IntPtr bitmap); }
    [DllImport("shell32.dll", CharSet=CharSet.Unicode, PreserveSig=true)]
    private static extern int SHCreateItemFromParsingName(string path, IntPtr context, ref Guid iid, [MarshalAs(UnmanagedType.Interface)] out ImageFactory factory);
    [DllImport("gdi32.dll")] public static extern bool DeleteObject(IntPtr bitmap);
    public static IntPtr LargeIconFor(string path) {
        ImageFactory factory = null;
        try {
            Guid iid = typeof(ImageFactory).GUID;
            if (SHCreateItemFromParsingName(path, IntPtr.Zero, ref iid, out factory) != 0) return IntPtr.Zero;
            IntPtr bitmap;
            return factory.GetImage(new Size { Width = 64, Height = 64 }, 5, out bitmap) == 0 ? bitmap : IntPtr.Zero;
        } catch { return IntPtr.Zero; }
        finally { if (factory != null) Marshal.ReleaseComObject(factory); }
    }
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] public struct Info {
        public IntPtr Icon; public int Index; public uint Attributes;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=260)] public string DisplayName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=80)] public string TypeName;
    }
    [DllImport("shell32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SHGetFileInfo(string path, uint attrs, out Info info, uint size, uint flags);
    [DllImport("user32.dll")] public static extern bool DestroyIcon(IntPtr icon);
    public static IntPtr IconFor(string path) {
        Info info;
        SHGetFileInfo(path, 0, out info, (uint)Marshal.SizeOf(typeof(Info)), 0x100);
        return info.Icon;
    }
}
'@
$script:dockSettingsPath = Join-Path $PSScriptRoot 'dock-settings.json'
$script:dockPaths = @('', '', '', '', '')
$desktopShortcuts = @(foreach ($folder in @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('CommonDesktopDirectory'))) {
    Get-ChildItem -LiteralPath $folder -Filter '*.lnk' -ErrorAction SilentlyContinue
})
$defaults = @('Google Chrome', 'Discord', 'Visual Studio Code', 'Obsidian', 'Steam')
for ($i = 0; $i -lt 5; $i++) {
    $match = $desktopShortcuts | Where-Object BaseName -eq $defaults[$i] | Select-Object -First 1
    if ($match) { $script:dockPaths[$i] = $match.FullName }
}
if (Test-Path -LiteralPath $dockSettingsPath) {
    try {
        $savedDock = Get-Content -LiteralPath $dockSettingsPath -Raw | ConvertFrom-Json
        for ($i = 0; $i -lt 5; $i++) {
            if ($i -lt $savedDock.shortcuts.Count) { $script:dockPaths[$i] = [string]$savedDock.shortcuts[$i] }
        }
    } catch { } # Keep usable defaults if the preferences file is invalid.
}
[xml]$dockXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 Title="App dock widget" Width="70" Height="276" WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True"
 Background="Transparent" ShowInTaskbar="False" ShowActivated="False" Opacity="0" FontFamily="Segoe UI" Foreground="White">
 <Grid Margin="4">
  <Grid.RenderTransform><TranslateTransform x:Name="DockSlide" X="-20"/></Grid.RenderTransform>
  <Border x:Name="DockGlass" CornerRadius="20" BorderThickness="1" Padding="7,8">
   <StackPanel x:Name="DockButtons"/>
  </Border>
 </Grid>
</Window>
'@
$script:dockWindow = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($dockXaml))
$dockWindow.Resources = $cornerTemplate.Resources
$dockWindow.FindName('DockGlass').Background = $glassSource.Background.Clone()
$dockWindow.FindName('DockGlass').BorderBrush = $glassSource.BorderBrush.Clone()
$script:dockEntry = @{ Name = 'Dock'; Window = $dockWindow; Slide = $dockWindow.FindName('DockSlide'); Handle = [IntPtr]::Zero; Visible = $false; LastNear = [DateTime]::MinValue; Offset = 4; Anchor = 'LeftCenter'; Configuring = $false }
$script:cornerCards += $dockEntry
$script:dockButtons = @()
$script:dockDragStart = $null
$script:dockSuppressClick = $false

function Save-DockSettings {
    try {
        @{ shortcuts = @($script:dockPaths) } | ConvertTo-Json | Set-Content -LiteralPath $dockSettingsPath -Encoding UTF8
        return $true
    } catch {
        [void][Windows.MessageBox]::Show('The shortcuts could not be saved. Please check the widget folder is writable.', 'App dock')
        return $false
    }
}

function Move-DockShortcut([int]$From, [int]$To) {
    if ($From -lt 0 -or $From -ge 5 -or $To -lt 0 -or $To -ge 5 -or $From -eq $To) { return }
    $before = @($script:dockPaths)
    $ordered = [Collections.Generic.List[string]]::new()
    foreach ($path in $script:dockPaths) { $ordered.Add($path) }
    $moving = $ordered[$From]
    $ordered.RemoveAt($From); $ordered.Insert($To, $moving)
    $script:dockPaths = @($ordered.ToArray())
    if (-not (Save-DockSettings)) { $script:dockPaths = $before }
    Update-DockButtons
}

function Set-DockHover($Button, [bool]$Hovered) {
    if ($Button.Content -isnot [Windows.Controls.Image]) { return }
    $duration = if ($script:widgetPreferences -and -not $script:widgetPreferences.motion) { 0 } else { 150 }
    $zoom = [Windows.Media.Animation.DoubleAnimation]::new($(if ($Hovered) { 1.12 } else { 1.0 }), [Windows.Duration]::new([TimeSpan]::FromMilliseconds($duration)))
    $zoom.EasingFunction = [Windows.Media.Animation.QuadraticEase]::new()
    $Button.Content.RenderTransform.BeginAnimation([Windows.Media.ScaleTransform]::ScaleXProperty, $zoom)
    $Button.Content.RenderTransform.BeginAnimation([Windows.Media.ScaleTransform]::ScaleYProperty, $zoom)
}

function Update-DockButtons {
    for ($slot = 0; $slot -lt 5; $slot++) {
        $button = $script:dockButtons[$slot]
        $path = $script:dockPaths[$slot]
        $button.Content = '+'
        $button.ToolTip = 'Choose app shortcut'
        if (-not $path) { continue }
        $button.ToolTip = [IO.Path]::GetFileNameWithoutExtension($path) + "`nDrag to reorder / Right-click to change"
        $button.Content = [IO.Path]::GetFileNameWithoutExtension($path).Substring(0,1)
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $button.ToolTip = 'Shortcut missing - click to replace'; continue }
        $bitmap = [DockNative]::LargeIconFor($path)
        $icon = [IntPtr]::Zero
        if ($bitmap -eq [IntPtr]::Zero) { $icon = [DockNative]::IconFor($path) }
        if ($bitmap -ne [IntPtr]::Zero -or $icon -ne [IntPtr]::Zero) {
            try {
                $source = if ($bitmap -ne [IntPtr]::Zero) {
                    [Windows.Interop.Imaging]::CreateBitmapSourceFromHBitmap($bitmap, [IntPtr]::Zero, [Windows.Int32Rect]::Empty, [Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions())
                } else { [Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon($icon, [Windows.Int32Rect]::Empty, [Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions()) }
                $source.Freeze()
                $image = [Windows.Controls.Image]::new()
                $image.Width = 30; $image.Height = 30; $image.Source = $source
                $image.RenderTransformOrigin = [Windows.Point]::new(0.5,0.5)
                $image.RenderTransform = [Windows.Media.ScaleTransform]::new(1,1)
                [Windows.Media.RenderOptions]::SetBitmapScalingMode($image, 'HighQuality')
                $button.Content = $image
            } finally {
                if ($bitmap -ne [IntPtr]::Zero) { [void][DockNative]::DeleteObject($bitmap) }
                if ($icon -ne [IntPtr]::Zero) { [void][DockNative]::DestroyIcon($icon) }
            }
        }
    }
}

function Select-DockShortcut([int]$Slot) {
    $script:dockEntry.Configuring = $true
    try {
        $picker = [Microsoft.Win32.OpenFileDialog]::new()
        $picker.Title = 'Choose an app shortcut for slot ' + ($Slot + 1)
        $picker.Filter = 'App shortcuts (*.lnk;*.url)|*.lnk;*.url'
        $picker.DereferenceLinks = $false
        $picker.InitialDirectory = [Environment]::GetFolderPath('Desktop')
        if ($picker.ShowDialog($dockWindow)) {
            $previous = $script:dockPaths[$Slot]
            $script:dockPaths[$Slot] = $picker.FileName
            if (-not (Save-DockSettings)) { $script:dockPaths[$Slot] = $previous }
            Update-DockButtons
        }
    } finally { $script:dockEntry.Configuring = $false; $script:dockEntry.LastNear = [DateTime]::Now }
}

[xml]$dockStyleXaml = @'
<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" TargetType="Button">
 <Setter Property="Background" Value="Transparent"/><Setter Property="Foreground" Value="White"/><Setter Property="FontSize" Value="24"/><Setter Property="Cursor" Value="Hand"/>
 <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
  <Border x:Name="Tile" Background="{TemplateBinding Background}" CornerRadius="14"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
  <ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Tile" Property="Background" Value="#25FFFFFF"/></Trigger><Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Tile" Property="BorderBrush" Value="#CCFFFFFF"/><Setter TargetName="Tile" Property="BorderThickness" Value="1"/></Trigger><Trigger Property="IsPressed" Value="True"><Setter TargetName="Tile" Property="Opacity" Value="0.65"/></Trigger></ControlTemplate.Triggers>
 </ControlTemplate></Setter.Value></Setter>
</Style>
'@
$script:dockIconStyle = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($dockStyleXaml))
$dockMenu = [Windows.Controls.ContextMenu]::new()
for ($i = 0; $i -lt 5; $i++) {
    $button = [Windows.Controls.Button]::new()
    $button.Style = $script:dockIconStyle
    $button.Width = 44; $button.Height = 46; $button.Margin = [Windows.Thickness]::new(0,2,0,2)
    $button.Tag = $i
    [Windows.Controls.ToolTipService]::SetPlacement($button, 'Right')
    [Windows.Controls.ToolTipService]::SetInitialShowDelay($button, 350)
    [Windows.Controls.ToolTipService]::SetShowDuration($button, 5000)
    $button.AllowDrop = $true
    $button.Add_MouseEnter({ param($sender, $eventArgs) Set-DockHover $sender $true })
    $button.Add_MouseLeave({ param($sender, $eventArgs) Set-DockHover $sender $false })
    $button.Add_PreviewMouseLeftButtonDown({
        param($sender, $eventArgs)
        $script:dockSuppressClick = $false
        $script:dockDragStart = $eventArgs.GetPosition($dockWindow)
    })
    $button.Add_PreviewMouseMove({
        param($sender, $eventArgs)
        if ($eventArgs.LeftButton -ne 'Pressed' -or $null -eq $script:dockDragStart) { return }
        $point = $eventArgs.GetPosition($dockWindow)
        if ([Math]::Abs($point.Y - $script:dockDragStart.Y) -lt [Windows.SystemParameters]::MinimumVerticalDragDistance -and [Math]::Abs($point.X - $script:dockDragStart.X) -lt [Windows.SystemParameters]::MinimumHorizontalDragDistance) { return }
        $script:dockDragStart = $null
        $script:dockSuppressClick = $true
        $script:dockEntry.Configuring = $true
        $sender.ReleaseMouseCapture()
        try {
            $data = [Windows.DataObject]::new('DesktopWidget.DockSlot', [int]$sender.Tag)
            [void][Windows.DragDrop]::DoDragDrop($sender, $data, [Windows.DragDropEffects]::Move)
        } finally {
            $script:dockEntry.Configuring = $false
            $script:dockEntry.LastNear = [DateTime]::Now
            foreach ($item in $script:dockButtons) { $item.Background = [Windows.Media.Brushes]::Transparent }
        }
        $eventArgs.Handled = $true
    })
    $button.Add_DragOver({
        param($sender, $eventArgs)
        $eventArgs.Effects = [Windows.DragDropEffects]::None
        if ($script:dockEntry.Configuring -and $eventArgs.Data.GetDataPresent('DesktopWidget.DockSlot')) {
            $eventArgs.Effects = [Windows.DragDropEffects]::Move
            $sender.Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#45FFFFFF')
        }
        $eventArgs.Handled = $true
    })
    $button.Add_DragLeave({ param($sender, $eventArgs) $sender.Background = [Windows.Media.Brushes]::Transparent })
    $button.Add_Drop({
        param($sender, $eventArgs)
        if ($script:dockEntry.Configuring -and $eventArgs.Data.GetDataPresent('DesktopWidget.DockSlot')) {
            Move-DockShortcut ([int]$eventArgs.Data.GetData('DesktopWidget.DockSlot')) ([int]$sender.Tag)
        }
        $sender.Background = [Windows.Media.Brushes]::Transparent
        $eventArgs.Handled = $true
    })
    $button.Add_Click({
        param($sender, $eventArgs)
        if ($script:dockSuppressClick) { $script:dockSuppressClick = $false; return }
        $slot = [int]$sender.Tag
        $path = $script:dockPaths[$slot]
        if (-not $path -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { Select-DockShortcut $slot; return }
        try {
            # Launch the shortcut itself to preserve arguments and working directory.
            $start = [Diagnostics.ProcessStartInfo]::new()
            $start.FileName = $path; $start.UseShellExecute = $true
            [void][Diagnostics.Process]::Start($start)
        } catch { [void][Windows.MessageBox]::Show('This shortcut could not be opened. Right-click the dock to choose another.', 'App dock') }
    })
    [void]$dockWindow.FindName('DockButtons').Children.Add($button)
    $script:dockButtons += $button
    $item = [Windows.Controls.MenuItem]::new()
    $item.Header = 'Change app ' + ($i + 1) + '...'; $item.Tag = $i
    $item.Add_Click({ param($sender, $eventArgs) Select-DockShortcut ([int]$sender.Tag) })
    [void]$dockMenu.Items.Add($item)
}
$dockWindow.ContextMenu = $dockMenu
Update-DockButtons

