param([switch]$Preview, [switch]$PreviewAll, [switch]$PreviewCorner, [switch]$Customize)
if ($PreviewCorner) { $Preview = $true }
if ($PreviewAll) { $Preview = $true }

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing
if ($Preview) { [Windows.Media.RenderOptions]::ProcessRenderMode = 'SoftwareOnly' }

$mutex = New-Object System.Threading.Mutex($false, 'Local\DesktopWidget.TimeAndDate')
if (-not $Preview -and -not $mutex.WaitOne(0)) {
    if ($Customize) { Set-Content -LiteralPath (Join-Path $PSScriptRoot 'customize.request') -Value 'open' }
    $mutex.Dispose(); exit
}

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class DesktopHost {
    public static long Candidate;
    public static int AttachError;
    public delegate bool EnumProc(IntPtr hwnd, IntPtr param);
    [DllImport("user32.dll")] public static extern IntPtr FindWindow(string cls, string title);
    [DllImport("user32.dll")] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc callback, IntPtr param);
    [DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr hwnd, uint msg, IntPtr wp, IntPtr lp, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", SetLastError=true)] public static extern IntPtr SetParent(IntPtr child, IntPtr parent);
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr hwnd, int index);
    [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr hwnd, int index, int value);
    [DllImport("user32.dll", EntryPoint="SetWindowLongPtrW")] public static extern IntPtr SetWindowLongPtr(IntPtr hwnd, int index, IntPtr value);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int w, int h, uint flags);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr hwnd, uint command);
    [StructLayout(LayoutKind.Sequential)] public struct Point { public int X; public int Y; }
    [DllImport("user32.dll")] public static extern bool ScreenToClient(IntPtr hwnd, ref Point point);
    public static void Position(IntPtr hwnd, IntPtr parent, int x, int y) {
        var point = new Point { X = x, Y = y };
        if (parent != IntPtr.Zero) ScreenToClient(parent, ref point);
        SetWindowPos(hwnd, IntPtr.Zero, point.X, point.Y, 0, 0, 0x0051);
    }
    public static IntPtr Attach(IntPtr hwnd) {
        IntPtr progman = FindWindow("Progman", null);
        if (progman == IntPtr.Zero) return IntPtr.Zero;
        // A transparent WPF window must remain top-level. Making it a layered
        // child of Explorer can report visible while drawing no pixels.
        // Desktop ownership keeps it above the wallpaper, below normal apps.
        Candidate = progman.ToInt64();
        SetWindowLongPtr(hwnd, -8, progman);
        SetWindowPos(hwnd, new IntPtr(1), 0, 0, 0, 0, 0x0053);
        return GetWindow(hwnd, 4) == progman ? progman : IntPtr.Zero;
    }
}
'@

# Original geometric letter shapes: no external font or image assets required.
$glyphs = @{
    A = 'M 0,58 L 20,0 40,58 M 10,37 L 30,37'
    D = 'M 0,0 L 23,0 40,17 40,41 23,58 0,58 M 0,16 L 0,42'
    E = 'M 40,0 L 0,0 0,58 40,58 M 0,29 L 30,29'
    F = 'M 40,0 L 0,0 0,58 M 0,29 L 30,29'
    H = 'M 0,0 L 0,58 M 40,0 L 40,58 M 0,29 L 40,29'
    I = 'M 20,0 L 20,58'
    M = 'M 0,58 L 0,0 20,28 40,0 40,58'
    N = 'M 0,58 L 0,0 40,58 40,0'
    O = 'M 12,0 L 28,0 40,12 40,46 28,58 12,58 0,46 0,12 Z'
    R = 'M 0,58 L 0,0 28,0 40,12 40,21 28,30 0,30 M 23,30 L 40,58'
    S = 'M 40,0 L 12,0 0,12 0,21 40,37 40,46 28,58 0,58'
    T = 'M 0,0 L 40,0 M 20,0 L 20,58'
    U = 'M 0,0 L 0,46 12,58 28,58 40,46 40,0'
    W = 'M 0,0 L 0,58 20,30 40,58 40,0'
    Y = 'M 0,0 L 20,29 40,0 M 20,29 L 20,58'
}

# Curved alternatives keep the geometric feel without faceted bowls or sharp caps.
$smoothGlyphs = $glyphs.Clone()
$smoothGlyphs.D = 'M 0,0 L 16,0 C 32,0 40,10 40,29 C 40,48 32,58 16,58 L 0,58 M 0,15 L 0,43'
$smoothGlyphs.O = 'M 20,0 C 5,0 0,9 0,29 C 0,49 5,58 20,58 C 35,58 40,49 40,29 C 40,9 35,0 20,0 Z'
$smoothGlyphs.R = 'M 0,58 L 0,0 23,0 C 46,0 46,30 23,30 L 0,30 M 23,30 L 40,58'
$smoothGlyphs.S = 'M 39,4 C 28,-3 1,-3 1,14 C 1,31 39,27 39,44 C 39,61 13,62 1,54'
$smoothGlyphs.U = 'M 0,0 L 0,38 C 0,65 40,65 40,38 L 40,0'

$styles = [ordered]@{
    'Smooth Mond' = @{ Geometric = $true; Smooth = $true; Font = 'Century Gothic'; Weight = 'Normal'; Size = 64; Italic = $false; Upper = $true }
    'Original Mond' = @{ Geometric = $true; Smooth = $false; Font = 'Century Gothic'; Weight = 'Normal'; Size = 64; Italic = $false; Upper = $true }
    'Minimal' = @{ Geometric = $false; Font = 'Segoe UI'; Weight = 'Light'; Size = 76; Italic = $false; Upper = $false }
    'Classic' = @{ Geometric = $false; Font = 'Georgia'; Weight = 'Normal'; Size = 70; Italic = $true; Upper = $false }
    'Bold' = @{ Geometric = $false; Font = 'Bahnschrift'; Weight = 'SemiBold'; Size = 70; Italic = $false; Upper = $true }
    'Digital' = @{ Geometric = $false; Font = 'Consolas'; Weight = 'Normal'; Size = 68; Italic = $false; Upper = $true }
}
$colors = [ordered]@{ 'White' = '#FFFFFF'; 'Warm ivory' = '#FFF0D4'; 'Ice blue' = '#BCE9FF'; 'Soft pink' = '#F8C9DC' }
$script:selectedStyle = 'Smooth Mond'
$script:selectedColor = 'White'
$settingsPath = Join-Path $PSScriptRoot 'settings.json'
if (Test-Path -LiteralPath $settingsPath) {
    try {
        $saved = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
        if ($styles.Contains($saved.style)) { $script:selectedStyle = $saved.style }
        if ($colors.Contains($saved.color)) { $script:selectedColor = $saved.color }
    } catch { } # An invalid preferences file falls back to safe defaults.
}

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Time and date widget" Width="720" Height="370"
        WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True"
        Background="Transparent" ShowInTaskbar="False" ShowActivated="False"
        Topmost="False" UseLayoutRounding="False"
        TextOptions.TextFormattingMode="Ideal" TextOptions.TextRenderingMode="Grayscale"
        RenderOptions.EdgeMode="Unspecified">
    <Window.Resources>
        <Style x:Key="MediaButton" TargetType="Button">
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Background" Value="#18FFFFFF"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="FontFamily" Value="Segoe UI"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Width" Value="56"/>
            <Setter Property="Height" Value="30"/>
            <Setter Property="Margin" Value="5,0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Surface" Background="{TemplateBinding Background}" CornerRadius="15">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Surface" Property="Background" Value="#38FFFFFF"/></Trigger>
                            <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.3"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Grid>
        <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
            <Viewbox Width="620" Height="86" Stretch="Uniform" StretchDirection="DownOnly" Margin="8,0,8,16">
                <Grid>
                    <Canvas x:Name="Day" Height="66"/>
                    <TextBlock x:Name="DayText" Visibility="Collapsed" TextAlignment="Center"/>
                </Grid>
            </Viewbox>
            <TextBlock x:Name="Time" FontFamily="Century Gothic" FontSize="28" Foreground="White" TextAlignment="Center"/>
            <TextBlock x:Name="Date" FontFamily="Century Gothic" FontSize="16" Foreground="#EEF0F4" TextAlignment="Center" Margin="0,8,0,0"/>
            <StackPanel x:Name="MediaPanel" Width="360" Margin="0,22,0,0" TextElement.Foreground="White" TextElement.FontFamily="Segoe UI">
                <TextBlock x:Name="MediaTitle" Text="Play a video to connect" FontSize="12" Opacity="0.8" TextAlignment="Center" TextTrimming="CharacterEllipsis" Margin="0,0,0,4"/>
                <Slider x:Name="MediaSeek" Minimum="0" Maximum="1" Value="0" Height="22" IsEnabled="False" IsMoveToPointEnabled="True" Foreground="White" Cursor="Hand" ToolTip="Drag or click to seek">
                    <Slider.Template>
                        <ControlTemplate TargetType="Slider">
                            <Grid>
                                <Border Height="3" Background="#45FFFFFF" CornerRadius="2"/>
                                <Track x:Name="PART_Track">
                                    <Track.DecreaseRepeatButton><RepeatButton Command="Slider.DecreaseLarge" Focusable="False"><RepeatButton.Template><ControlTemplate><Border Height="3" Background="{Binding Foreground, RelativeSource={RelativeSource AncestorType=Slider}}" CornerRadius="2"/></ControlTemplate></RepeatButton.Template></RepeatButton></Track.DecreaseRepeatButton>
                                    <Track.Thumb><Thumb Width="10" Height="10"><Thumb.Template><ControlTemplate><Ellipse Fill="{Binding Foreground, RelativeSource={RelativeSource AncestorType=Slider}}"/></ControlTemplate></Thumb.Template></Thumb></Track.Thumb>
                                    <Track.IncreaseRepeatButton><RepeatButton Command="Slider.IncreaseLarge" Focusable="False"><RepeatButton.Template><ControlTemplate><Border Background="Transparent"/></ControlTemplate></RepeatButton.Template></RepeatButton></Track.IncreaseRepeatButton>
                                </Track>
                            </Grid>
                            <ControlTemplate.Triggers><Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.3"/></Trigger></ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Slider.Template>
                </Slider>
                <Grid Margin="0,0,0,7">
                    <TextBlock x:Name="MediaElapsed" Text="--:--" FontSize="11" Opacity="0.65" HorizontalAlignment="Left"/>
                    <TextBlock x:Name="MediaDuration" Text="--:--" FontSize="11" Opacity="0.65" HorizontalAlignment="Right"/>
                </Grid>
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                    <Button x:Name="MediaBack" Content="-10 s" Style="{StaticResource MediaButton}" ToolTip="Back 10 seconds" IsEnabled="False"/>
                    <Button x:Name="MediaPlay" Content="Play" Style="{StaticResource MediaButton}" ToolTip="Play or pause" IsEnabled="False"/>
                    <Button x:Name="MediaForward" Content="+10 s" Style="{StaticResource MediaButton}" ToolTip="Forward 10 seconds" IsEnabled="False"/>
                </StackPanel>
            </StackPanel>
        </StackPanel>
    </Grid>
</Window>
'@
$window = [Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $xaml))
$dayCanvas = $window.FindName('Day')
$dayText = $window.FindName('DayText')
$timeText = $window.FindName('Time')
$dateText = $window.FindName('Date')
$script:lastDay = ''
$script:hostWindow = [IntPtr]::Zero
$script:hwnd = [IntPtr]::Zero
$culture = [Globalization.CultureInfo]::InvariantCulture
. (Join-Path $PSScriptRoot 'MediaControls.ps1')
. (Join-Path $PSScriptRoot 'CornerWidgets.ps1')
. (Join-Path $PSScriptRoot 'WidgetCustomization.ps1')
. (Join-Path $PSScriptRoot 'WidgetSettings.ps1')
. (Join-Path $PSScriptRoot 'AppSearch.ps1')

function Update-Clock {
    # Read the wall clock anew each tick, including after sleep or a time-zone change.
    $now = [DateTime]::Now
    $timeText.Text = $now.ToString((Get-WidgetTimeFormat), $culture)
    $dateText.Text = $now.ToString($script:widgetPreferences.dateFormat, $culture)
    $fullDay = $now.ToString('dddd', $culture)
    $day = $fullDay.ToUpperInvariant()
    $appearanceKey = "$day/$script:selectedStyle/$script:selectedColor"
    if ($appearanceKey -ne $script:lastDay) {
        $design = $styles[$script:selectedStyle]
        $brush = [Windows.Media.BrushConverter]::new().ConvertFromString($colors[$script:selectedColor])
        $timeText.Foreground = $brush
        $dateText.Foreground = $brush
        $mediaSeek.Foreground = $brush
        $mediaPanel.SetValue([Windows.Documents.TextElement]::ForegroundProperty, $brush)
        foreach ($button in @($mediaBack, $mediaPlay, $mediaForward)) { $button.Foreground = $brush }
        $dateText.Opacity = 0.85
        $timeText.FontFamily = [Windows.Media.FontFamily]::new($design.Font)
        $dateText.FontFamily = [Windows.Media.FontFamily]::new($design.Font)
        $dayText.Foreground = $brush
        $dayText.FontFamily = [Windows.Media.FontFamily]::new($design.Font)
        $dayText.FontWeight = [Windows.FontWeightConverter]::new().ConvertFromString($design.Weight)
        $dayText.FontSize = $design.Size
        $dayText.FontStyle = if ($design.Italic) { [Windows.FontStyles]::Italic } else { [Windows.FontStyles]::Normal }
        $dayText.Text = if ($design.Upper) { $day } else { $fullDay }
        $dayCanvas.Visibility = if ($design.Geometric) { 'Visible' } else { 'Collapsed' }
        $dayText.Visibility = if ($design.Geometric) { 'Collapsed' } else { 'Visible' }
        $dayCanvas.Children.Clear()
        $dayCanvas.Width = $day.Length * 60 - 16
        for ($i = 0; $design.Geometric -and $i -lt $day.Length; $i++) {
            $path = New-Object Windows.Shapes.Path
            $letterSet = if ($design.Smooth) { $smoothGlyphs } else { $glyphs }
            $path.Data = [Windows.Media.Geometry]::Parse($letterSet[[string]$day[$i]])
            $path.Stroke = $brush
            $path.StrokeThickness = 2.5
            $path.StrokeLineJoin = [Windows.Media.PenLineJoin]::Round
            $path.StrokeStartLineCap = [Windows.Media.PenLineCap]::Round
            $path.StrokeEndLineCap = [Windows.Media.PenLineCap]::Round
            [Windows.Controls.Canvas]::SetLeft($path, $i * 60 + 2)
            [Windows.Controls.Canvas]::SetTop($path, 3)
            [void]$dayCanvas.Children.Add($path)
        }
        $script:lastDay = $appearanceKey
    }
}

function Center-Widget {
    $work = [Windows.SystemParameters]::WorkArea
    $window.Left = [Math]::Max($work.Left, [Math]::Min($work.Right - $window.Width, ($work.Left + ($work.Width - $window.Width) / 2 + $script:widgetPreferences.clockX)))
    $window.Top = [Math]::Max($work.Top, [Math]::Min($work.Bottom - $window.Height, ($work.Top + ($work.Height - $window.Height) / 2 + $script:widgetPreferences.clockY)))
    # WPF uses device-independent coordinates; don't mix these with Win32 pixels.
}

Update-Clock
Center-Widget
$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(1)
$timer.Add_Tick({
    Update-Clock
    Update-Media
    if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'customize.request')) {
        Remove-Item -LiteralPath (Join-Path $PSScriptRoot 'customize.request') -Force
        Show-WidgetSettings
    }
    if ($script:hwnd -ne [IntPtr]::Zero -and -not $menu.IsOpen) {
        [void][DesktopHost]::SetWindowPos($script:hwnd, [IntPtr]1, 0, 0, 0, 0, 0x0053)
    }
    if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'stop.request')) {
        Remove-Item -LiteralPath (Join-Path $PSScriptRoot 'stop.request') -Force
        $window.Close()
    }
})

$menu = New-Object Windows.Controls.ContextMenu
$styleMenu = New-Object Windows.Controls.MenuItem
$styleMenu.Header = 'Style'
$colorMenu = New-Object Windows.Controls.MenuItem
$colorMenu.Header = 'Text color'
function Save-Appearance {
    $script:widgetPreferences.clockStyle = $script:selectedStyle
    $script:widgetPreferences.clockColor = $script:selectedColor
    foreach ($item in $styleMenu.Items) { $item.IsChecked = $item.Header -eq $script:selectedStyle }
    foreach ($item in $colorMenu.Items) { $item.IsChecked = $item.Header -eq $script:selectedColor }
    Update-Clock
    if ($Preview) { return }
    try {
        Save-WidgetPreferences
        @{ style = $script:selectedStyle; color = $script:selectedColor } | ConvertTo-Json | Set-Content -LiteralPath $settingsPath -Encoding UTF8
    } catch {
        [void][Windows.MessageBox]::Show('Your style has changed, but the preference could not be saved to the widget folder.', 'Widget preferences')
    }
}
foreach ($name in $styles.Keys) {
    $item = New-Object Windows.Controls.MenuItem
    $item.Header = $name
    $item.IsCheckable = $true
    $item.IsChecked = $name -eq $script:selectedStyle
    $item.Add_Click({ param($sender, $eventArgs) $script:selectedStyle = [string]$sender.Header; Save-Appearance })
    [void]$styleMenu.Items.Add($item)
}
foreach ($name in $colors.Keys) {
    $item = New-Object Windows.Controls.MenuItem
    $item.Header = $name
    $item.IsCheckable = $true
    $item.IsChecked = $name -eq $script:selectedColor
    $item.Add_Click({ param($sender, $eventArgs) $script:selectedColor = [string]$sender.Header; Save-Appearance })
    [void]$colorMenu.Items.Add($item)
}
[void]$menu.Items.Add($styleMenu)
[void]$menu.Items.Add($colorMenu)
[void]$menu.Items.Add((New-Object Windows.Controls.Separator))
$center = New-Object Windows.Controls.MenuItem
$center.Header = 'Center on screen'
$center.Add_Click({ $script:widgetPreferences.clockX = 0; $script:widgetPreferences.clockY = 0; Center-Widget; try { Save-WidgetPreferences } catch { [void][Windows.MessageBox]::Show('Position could not be saved.', 'Widget settings') } })
[void]$menu.Items.Add($center)
$close = New-Object Windows.Controls.MenuItem
$close.Header = 'Close widget'
$close.Add_Click({ $window.Close() })
[void]$menu.Items.Add($close)
$window.ContextMenu = $menu
Initialize-WidgetCustomization

$window.Add_SourceInitialized({
    $script:hwnd = (New-Object Windows.Interop.WindowInteropHelper($window)).Handle
    $style = [DesktopHost]::GetWindowLong($script:hwnd, -20)
    [void][DesktopHost]::SetWindowLong($script:hwnd, -20, ($style -bor 0x80 -bor 0x08000000))
})

$window.Add_Loaded({
    if ($Preview) {
        if ($PreviewCorner) { Save-CornerPreview; $window.Close(); return }
        $previewStyles = if ($PreviewAll) { @($styles.Keys) } else { @($script:selectedStyle) }
        foreach ($previewStyle in $previewStyles) {
            # Exercise the same routed click handler used by the live menu.
            $choice = $styleMenu.Items | Where-Object { $_.Header -eq $previewStyle }
            $choice.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
            if ($script:selectedStyle -ne $previewStyle -or -not $choice.IsChecked) {
                throw "Style selection failed: $previewStyle"
            }
            $window.UpdateLayout()
            $bitmap = New-Object Windows.Media.Imaging.RenderTargetBitmap(1440, 740, 192, 192, [Windows.Media.PixelFormats]::Pbgra32)
            $bitmap.Render($window)
            $encoder = New-Object Windows.Media.Imaging.PngBitmapEncoder
            $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
            $fileName = if ($PreviewAll) { 'preview-' + $previewStyle.Replace(' ', '-') + '.png' } else { 'preview.png' }
            $stream = [IO.File]::Create((Join-Path $PSScriptRoot $fileName))
            try { $encoder.Save($stream) } finally { $stream.Dispose() }
        }
        $window.Close()
        return
    }
    $script:hostWindow = [DesktopHost]::Attach($script:hwnd)
    Center-Widget
    $status = [ordered]@{ started = [DateTime]::Now.ToString('o'); processId = $PID; desktopAttached = ($script:hostWindow -ne [IntPtr]::Zero); desktopCandidate = [DesktopHost]::Candidate; attachError = [DesktopHost]::AttachError; windowHandle = $script:hwnd.ToInt64(); style = $script:selectedStyle; weekday = [DateTime]::Now.DayOfWeek.ToString(); time = $timeText.Text; date = $dateText.Text }
    $status | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'status.json') -Encoding UTF8
    $timer.Start()
    Start-Media
    Start-CornerWidgets
    Start-AppSearchHotkey
    if ($Customize) { Show-WidgetSettings }
})

try {
    if (-not $Preview) {
        Remove-Item -LiteralPath (Join-Path $PSScriptRoot 'stop.request') -ErrorAction SilentlyContinue
    }
    [void]$window.ShowDialog()
} finally {
    if (-not $Preview) { Stop-AppSearch }
    Stop-TaskbarGuard
    if (-not $Preview) { Save-QuickNote }
    if (-not $Preview) { Save-CompanionState }
    if (-not $Preview -and $script:petToast) { $script:petToast.Close() }
    if ($script:noteSaveTimer) { $script:noteSaveTimer.Stop() }
    $timer.Stop()
    if ($script:cornerTimer) { $script:cornerTimer.Stop() }
    if ($script:weatherClient) { $script:weatherClient.Dispose() }
    if ($script:settingsWindow) { $script:settingsWindow.Close() }
    if (-not $Preview) { foreach ($entry in $script:cornerCards) { $entry.Window.Close() } }
    if (-not $Preview) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
