# Calendar and battery shelf. Loaded into the clock's existing WPF process.
Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class CornerNative {
    [StructLayout(LayoutKind.Sequential)] public struct Point { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] public struct Power {
        public byte ACLineStatus, BatteryFlag, BatteryLifePercent, SystemStatusFlag;
        public uint BatteryLifeTime, BatteryFullLifeTime;
    }
    [DllImport("user32.dll")] public static extern bool GetPhysicalCursorPos(out Point p);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder text, int count);
    [DllImport("kernel32.dll")] public static extern bool GetSystemPowerStatus(out Power power);
    public static Point Cursor() { Point p; GetPhysicalCursorPos(out p); return p; }
    public static string ClassName(IntPtr h) { var text = new StringBuilder(256); GetClassName(h, text, 256); return text.ToString(); }
    public static Power ReadPower() { Power p; if (!GetSystemPowerStatus(out p)) p.BatteryLifePercent = 255; return p; }
}
'@

function Get-CalendarCells([DateTime]$Month, [DateTime]$Today = [DateTime]::Today) {
    $first = [DateTime]::new($Month.Year, $Month.Month, 1)
    $offset = (([int]$first.DayOfWeek + 6) % 7)
    $days = [DateTime]::DaysInMonth($Month.Year, $Month.Month)
    for ($index = 0; $index -lt 42; $index++) {
        $number = $index - $offset + 1
        $valid = $number -ge 1 -and $number -le $days
        [pscustomobject]@{
            Label = if ($valid) { [string]$number } else { '' }
            Today = $valid -and $number -eq $Today.Day -and $Month.Month -eq $Today.Month -and $Month.Year -eq $Today.Year
            Weekend = $index % 7 -ge 5
        }
    }
}

[xml]$cornerXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Calendar and battery widgets" Width="526" Height="258"
        WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True"
        Background="Transparent" ShowInTaskbar="False" ShowActivated="False"
        Topmost="False" Opacity="0" TextOptions.TextRenderingMode="Grayscale"
        TextOptions.TextFormattingMode="Ideal" FontFamily="Segoe UI" Foreground="White">
    <Window.Resources>
        <Style x:Key="Nav" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#DCE8FA"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="FontSize" Value="16"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
                <Border x:Name="NavSurface" Background="{TemplateBinding Background}" CornerRadius="7" Padding="6,2">
                    <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                </Border>
                <ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="NavSurface" Property="Background" Value="#30FFFFFF"/></Trigger></ControlTemplate.Triggers>
            </ControlTemplate></Setter.Value></Setter>
        </Style>
    </Window.Resources>
    <Grid x:Name="CornerSurface" Margin="8">
        <Grid.RenderTransform><TranslateTransform x:Name="Slide" X="-14"/></Grid.RenderTransform>
        <Grid.ColumnDefinitions><ColumnDefinition Width="266"/><ColumnDefinition Width="14"/><ColumnDefinition Width="230"/></Grid.ColumnDefinitions>
        <Border x:Name="CalendarCard" Grid.Column="0" BorderThickness="1.2" CornerRadius="24" Padding="18,15">
            <Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="0.8,1"><GradientStop Color="#806F8299" Offset="0"/><GradientStop Color="#483D5068" Offset="0.38"/><GradientStop Color="#70405066" Offset="1"/></LinearGradientBrush></Border.Background>
            <Border.BorderBrush><LinearGradientBrush StartPoint="0,0" EndPoint="1,1"><GradientStop Color="#D0FFFFFF" Offset="0"/><GradientStop Color="#35FFFFFF" Offset="0.45"/><GradientStop Color="#15FFFFFF" Offset="0.7"/><GradientStop Color="#85DCEBFF" Offset="1"/></LinearGradientBrush></Border.BorderBrush>
            <Grid>
                <Grid.RowDefinitions><RowDefinition Height="32"/><RowDefinition Height="22"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                <Grid>
                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="26"/><ColumnDefinition Width="26"/></Grid.ColumnDefinitions>
                    <Button x:Name="CalendarMonth" Style="{StaticResource Nav}" FontSize="12" FontWeight="SemiBold" HorizontalAlignment="Left" ToolTip="Return to the current month"/>
                    <Button x:Name="PreviousMonth" Grid.Column="1" Content="&#x2039;" Style="{StaticResource Nav}" ToolTip="Previous month"/>
                    <Button x:Name="NextMonth" Grid.Column="2" Content="&#x203A;" Style="{StaticResource Nav}" ToolTip="Next month"/>
                </Grid>
                <UniformGrid Grid.Row="1" Rows="1" Columns="7" TextElement.FontSize="11" TextElement.Foreground="#90BBD0EB">
                    <TextBlock Text="M" HorizontalAlignment="Center"/><TextBlock Text="T" HorizontalAlignment="Center"/><TextBlock Text="W" HorizontalAlignment="Center"/><TextBlock Text="T" HorizontalAlignment="Center"/><TextBlock Text="F" HorizontalAlignment="Center"/><TextBlock Text="S" HorizontalAlignment="Center"/><TextBlock Text="S" HorizontalAlignment="Center"/>
                </UniformGrid>
                <UniformGrid x:Name="CalendarDays" Grid.Row="2" Rows="6" Columns="7"/>
            </Grid>
        </Border>
        <Border x:Name="BatteryCard" Grid.Column="2" BorderThickness="1.2" CornerRadius="24" Padding="18,15">
            <Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="0.8,1"><GradientStop Color="#806F8299" Offset="0"/><GradientStop Color="#483D5068" Offset="0.38"/><GradientStop Color="#70405066" Offset="1"/></LinearGradientBrush></Border.Background>
            <Border.BorderBrush><LinearGradientBrush StartPoint="0,0" EndPoint="1,1"><GradientStop Color="#D0FFFFFF" Offset="0"/><GradientStop Color="#35FFFFFF" Offset="0.45"/><GradientStop Color="#15FFFFFF" Offset="0.7"/><GradientStop Color="#85DCEBFF" Offset="1"/></LinearGradientBrush></Border.BorderBrush>
            <StackPanel>
                <TextBlock Text="BATTERY" FontSize="11" FontWeight="SemiBold" Foreground="#BBD0EB" Margin="2,3,0,12"/>
                <Grid Width="100" Height="100" HorizontalAlignment="Center">
                    <Ellipse Width="90" Height="90" Stroke="#25FFFFFF" StrokeThickness="6"/>
                    <Path x:Name="BatteryArc" Stroke="#D4EAFF" StrokeThickness="6" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
                    <Path Data="M 32,37 L 68,37 68,61 32,61 Z M 25,65 L 75,65" Stroke="#E7F2FF" StrokeThickness="2" StrokeLineJoin="Round" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
                </Grid>
                <TextBlock x:Name="BatteryPercent" Text="--%" FontSize="27" FontWeight="Light" HorizontalAlignment="Center" Margin="0,9,0,2"/>
                <TextBlock x:Name="BatteryState" Text="Reading battery" FontSize="11" Foreground="#BBD0EB" HorizontalAlignment="Center"/>
            </StackPanel>
        </Border>
    </Grid>
</Window>
'@
$script:cornerWindow = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($cornerXaml))
$script:cornerHandle = [IntPtr]::Zero
$script:cornerVisible = $false
$script:cornerLastNear = [DateTime]::MinValue
$script:cornerRefresh = [DateTime]::MinValue
$script:calendarOffset = 0
$script:calendarDate = ''
$script:cornerTimer = $null
$calendarMonth = $cornerWindow.FindName('CalendarMonth')
$calendarDays = $cornerWindow.FindName('CalendarDays')
$batteryPercent = $cornerWindow.FindName('BatteryPercent')
$batteryState = $cornerWindow.FindName('BatteryState')
$batteryArc = $cornerWindow.FindName('BatteryArc')
$cornerSlide = $cornerWindow.FindName('Slide')

# Give each card its own native window, hit area and animation state.
# The old window serves only as a XAML resource/name scope during construction.
$cornerTemplate = $cornerWindow
$script:cornerCards = @()
foreach ($spec in @(
    @{ Name = 'Calendar'; Element = 'CalendarCard'; SourceWidth = 266; Width = 214; Left = 10 },
    @{ Name = 'Battery'; Element = 'BatteryCard'; SourceWidth = 230; Width = 186; Left = 238 }
)) {
    $card = $cornerTemplate.FindName($spec.Element)
    $card.Parent.Children.Remove($card)
    $card.Width = $spec.SourceWidth
    $card.Height = 242
    [Windows.Controls.Grid]::SetColumn($card, 0)
    $glass = [Windows.Controls.Grid]::new()
    $glass.Width = $spec.SourceWidth
    $glass.Height = 242
    [void]$glass.Children.Add($card)
    # Inset specular rim: transparent center leaves the actual desktop visible.
    $rim = [Windows.Controls.Border]::new()
    $rim.Margin = [Windows.Thickness]::new(2)
    $rim.CornerRadius = [Windows.CornerRadius]::new(22)
    $rim.BorderThickness = [Windows.Thickness]::new(0.7)
    $rim.BorderBrush = [Windows.Media.BrushConverter]::new().ConvertFromString('#28FFFFFF')
    $rim.IsHitTestVisible = $false
    [void]$glass.Children.Add($rim)
    $view = [Windows.Controls.Viewbox]::new()
    $view.Margin = [Windows.Thickness]::new(4,24,4,4)
    $view.Stretch = 'Uniform'
    $view.Child = $glass
    $slide = [Windows.Media.TranslateTransform]::new(0,-20)
    $view.RenderTransform = $slide
    $win = [Windows.Window]::new()
    $win.Title = "$($spec.Name) glass widget"
    $win.Width = $spec.Width
    $win.Height = 216
    $win.WindowStyle = 'None'
    $win.ResizeMode = 'NoResize'
    $win.AllowsTransparency = $true
    $win.Background = [Windows.Media.Brushes]::Transparent
    $win.ShowInTaskbar = $false
    $win.ShowActivated = $false
    $win.Opacity = 0
    $win.FontFamily = [Windows.Media.FontFamily]::new('Segoe UI')
    $win.Foreground = [Windows.Media.Brushes]::White
    $win.Resources = $cornerTemplate.Resources
    [Windows.Media.TextOptions]::SetTextRenderingMode($win, 'Grayscale')
    $win.Content = $view
    $script:cornerCards += @{ Name = $spec.Name; Window = $win; Slide = $slide; Handle = [IntPtr]::Zero; Visible = $false; LastNear = [DateTime]::MinValue; Offset = $spec.Left }
}
$script:cornerWindow = $cornerCards[0].Window
. (Join-Path $PSScriptRoot 'WeatherWidget.ps1')
. (Join-Path $PSScriptRoot 'PhotoWidget.ps1')
. (Join-Path $PSScriptRoot 'AppDock.ps1')
. (Join-Path $PSScriptRoot 'MacDock.ps1')
. (Join-Path $PSScriptRoot 'TopMenuBar.ps1')
. (Join-Path $PSScriptRoot 'QuickNote.ps1')
. (Join-Path $PSScriptRoot 'SystemMonitor.ps1')
. (Join-Path $PSScriptRoot 'QuickFolders.ps1')
. (Join-Path $PSScriptRoot 'CompanionWidgets.ps1')

function Update-CornerCalendar {
    $month = [DateTime]::Today.AddMonths($script:calendarOffset)
    $calendarMonth.Content = $month.ToString('MMMM yyyy', [Globalization.CultureInfo]::InvariantCulture).ToUpperInvariant()
    $calendarDays.Children.Clear()
    foreach ($cell in (Get-CalendarCells $month)) {
        $border = [Windows.Controls.Border]::new()
        $border.Width = 25
        $border.Height = 25
        $border.CornerRadius = [Windows.CornerRadius]::new(12.5)
        $border.HorizontalAlignment = 'Center'
        $border.VerticalAlignment = 'Center'
        $label = [Windows.Controls.TextBlock]::new()
        $label.Text = $cell.Label
        $label.FontSize = 12
        $label.HorizontalAlignment = 'Center'
        $label.VerticalAlignment = 'Center'
        if ($cell.Today) {
            $border.Background = if ($script:widgetPreferences) { [Windows.Media.BrushConverter]::new().ConvertFromString($script:widgetAccents[$script:widgetPreferences.accent]) } else { [Windows.Media.Brushes]::White }
            $label.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#263348')
            $label.FontWeight = [Windows.FontWeights]::SemiBold
        } elseif ($cell.Weekend) { $label.Opacity = 0.55 }
        $border.Child = $label
        [void]$calendarDays.Children.Add($border)
    }
    $script:calendarDate = [DateTime]::Today.ToString('yyyy-MM-dd')
}

function Update-CornerBattery {
    $power = [CornerNative]::ReadPower()
    $hasBattery = ($power.BatteryFlag -band 128) -eq 0 -and $power.BatteryFlag -ne 255
    $known = $hasBattery -and $power.BatteryLifePercent -le 100
    $batteryPercent.Text = if (-not $hasBattery) { 'Desktop PC' } elseif ($known) { "$($power.BatteryLifePercent)%" } else { '--%' }
    $batteryPercent.FontSize = if ($hasBattery) { 27 } else { 22 }
    $batteryState.Text = if (-not $hasBattery) { 'No battery detected' } elseif (-not $known) { 'Battery status unavailable' } elseif (($power.BatteryFlag -band 8) -ne 0) { 'Charging' } elseif ($power.ACLineStatus -eq 1) { 'Plugged in' } else { 'On battery' }
    $batteryArc.Data = $null
    if ($known -and $power.BatteryLifePercent -gt 0) {
        $fraction = [Math]::Min(0.99999, $power.BatteryLifePercent / 100.0)
        $angle = 2 * [Math]::PI * $fraction
        $end = [Windows.Point]::new(50 + 45 * [Math]::Sin($angle), 50 - 45 * [Math]::Cos($angle))
        $figure = [Windows.Media.PathFigure]::new()
        $figure.StartPoint = [Windows.Point]::new(50,5)
        $segment = [Windows.Media.ArcSegment]::new($end, [Windows.Size]::new(45,45), 0, ($fraction -gt 0.5), [Windows.Media.SweepDirection]::Clockwise, $true)
        $figure.Segments.Add($segment)
        $geometry = [Windows.Media.PathGeometry]::new()
        $geometry.Figures.Add($figure)
        $batteryArc.Data = $geometry
        $color = if ($power.BatteryLifePercent -le 20) { '#FFB5A7' } elseif (($power.BatteryFlag -band 8) -ne 0) { '#B8EFCE' } elseif ($script:widgetPreferences) { $script:widgetAccents[$script:widgetPreferences.accent] } else { '#D4EAFF' }
        $batteryArc.Stroke = [Windows.Media.BrushConverter]::new().ConvertFromString($color)
    }
}

function Set-CornerVisible([bool]$Visible, $Card = $script:cornerCards[0]) {
    if ($Visible -eq $Card.Visible) { return }
    $Card.Visible = $Visible
    $style = [DesktopHost]::GetWindowLong($Card.Handle, -20)
    # Hidden cards must not intercept desktop icons or clicks.
    $style = if ($Visible) { $style -band (-bnot 0x20) } else { $style -bor 0x20 }
    [void][DesktopHost]::SetWindowLong($Card.Handle, -20, $style)
    $milliseconds = if ($script:widgetPreferences -and -not $script:widgetPreferences.motion) { 0 } else { 220 }
    $duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds($milliseconds))
    $fade = [Windows.Media.Animation.DoubleAnimation]::new($(if ($Visible) { 1.0 } else { 0.0 }), $duration)
    $slide = [Windows.Media.Animation.DoubleAnimation]::new($(if ($Visible) { 0.0 } elseif ($Card.Anchor -in @('RightCenter','BottomCenter')) { 20.0 } else { -20.0 }), $duration)
    $ease = [Windows.Media.Animation.CubicEase]::new()
    $ease.EasingMode = 'EaseOut'
    $fade.EasingFunction = $ease
    $slide.EasingFunction = $ease
    $Card.Window.BeginAnimation([Windows.UIElement]::OpacityProperty, $fade)
    $axis = if ($Card.Anchor -in @('LeftCenter','RightCenter')) { [Windows.Media.TranslateTransform]::XProperty } else { [Windows.Media.TranslateTransform]::YProperty }
    $Card.Slide.BeginAnimation($axis, $slide)
}

function Test-CornerProximity([double]$X, [double]$Y, [double]$Width = 214, [double]$Height = 216) {
    return $X -ge -10 -and $X -le ($Width + 10) -and $Y -ge -20 -and $Y -le ($Height + 10)
}

function Get-WidgetPlacement($Entry, $Work = [Windows.SystemParameters]::WorkArea) {
    # Keep the photo next to weather and the note below it as sizes change.
    if ($Entry.Name -eq 'TopBar') {
        $Entry.Window.Width = $Work.Width
        return [Windows.Point]::new($Work.Left, $Work.Top)
    }
    $offset = $Entry.Offset
    $topOffset = $Entry.TopOffset
    if ($Entry.Name -eq 'Battery') { $offset = 10 + $script:cornerCards[0].Window.Width + 14 }
    if ($Entry.Name -eq 'Photo') { $offset = 10 + $weatherWindow.Width + 14 }
    if ($Entry.Name -eq 'QuickNote') { $topOffset = $weatherWindow.Height + 4 }
    $left = $Work.Left + $offset
    $top = $Work.Top + 2 + $topOffset
    if ($Entry.Anchor -in @('Right','RightCenter')) { $left = $Work.Right - $Entry.Window.Width - $offset }
    if ($script:widgetPreferences.widgets.TopBar.enabled -and $Entry.Anchor -notin @('BottomLeft','BottomCenter','LeftCenter','RightCenter')) { $top += $script:topBarWindow.Height }
    if ($Entry.Name -eq 'MacDock') { $Entry.Window.Width = $Work.Width * $script:widgetPreferences.dockWidth / 100 }
    if ($Entry.Anchor -eq 'BottomCenter') { $left = $Work.Left + ($Work.Width - $Entry.Window.Width) / 2; $top = $Work.Bottom - $Entry.Window.Height - 6 }
    if ($Entry.Anchor -eq 'TopCenter') { $left = $Work.Left + ($Work.Width - $Entry.Window.Width) / 2 }
    if ($Entry.Anchor -eq 'BottomLeft') { $top = $Work.Bottom - $Entry.Window.Height - 12 }
    if ($Entry.Anchor -in @('LeftCenter','RightCenter')) { $top = $Work.Top + ($Work.Height - $Entry.Window.Height) / 2 }
    if ($Entry.Anchor -eq 'RightCenter') {
        $noteBottom = $Work.Top + 2 + $weatherWindow.Height + 4 + $script:noteWindow.Height
        if ($script:widgetPreferences.widgets.TopBar.enabled) { $noteBottom += $script:topBarWindow.Height }
        if ($script:widgetPreferences) { $noteBottom += $script:widgetPreferences.widgets.QuickNote.y }
        $top = [Math]::Max($top, $noteBottom + 12)
        if ($top + $Entry.Window.Height -gt $Work.Bottom - 4) {
            # Short/scaled screens: stay on the right, beside the existing cards.
            $left = $Work.Right - $script:noteWindow.Width - 24 - $Entry.Window.Width
            $top = $Work.Top + ($Work.Height - $Entry.Window.Height) / 2
        }
    }
    if ($script:widgetPreferences) {
        $choice = $script:widgetPreferences.widgets[$Entry.Name]
        $left += $choice.x; $top += $choice.y
    }
    $left = [Math]::Max($Work.Left, [Math]::Min($Work.Right - $Entry.Window.Width,$left))
    $top = [Math]::Max($Work.Top, [Math]::Min($Work.Bottom - $Entry.Window.Height,$top))
    return [Windows.Point]::new($left,$top)
}

function Test-TopBarDwell($Entry, [bool]$NearEdge, [DateTime]$Now = [DateTime]::Now) {
    if (-not $NearEdge) { $Entry.HoverStarted = $null; return $false }
    if ($null -eq $Entry.HoverStarted) { $Entry.HoverStarted = $Now }
    return ($Now - $Entry.HoverStarted).TotalMilliseconds -ge 1000
}
function Test-MacDockReveal($Entry, [bool]$Desktop, [bool]$Edge, [bool]$Near, [bool]$Interacting, [DateTime]$Now = [DateTime]::Now) {
    $delay = if ($script:widgetPreferences) { $script:widgetPreferences.hideDelay } else { 600 }
    if ($Desktop) {
        $Entry.AppRevealed = $false; $Entry.HoverStarted = $null
        if ($Entry.Pinned -or $Near -or $Interacting) { $Entry.LastNear = $Now; return $true }
        return $Entry.Visible -and ($Now - $Entry.LastNear).TotalMilliseconds -le $delay
    }
    if ($Interacting) { $Entry.AppRevealed = $true; $Entry.LastNear = $Now; return $true }
    if (-not $Entry.AppRevealed) {
        if (-not (Test-TopBarDwell $Entry $Edge $Now)) { return $false }
        $Entry.AppRevealed = $true; $Entry.LastNear = $Now
    }
    if ($Near -or $Edge) { $Entry.LastNear = $Now; return $true }
    if (($Now - $Entry.LastNear).TotalMilliseconds -le $delay) { return $true }
    $Entry.AppRevealed = $false; $Entry.HoverStarted = $null
    return $false
}
function Update-CornerHover {
    $work = [Windows.SystemParameters]::WorkArea
    $cursor = [CornerNative]::Cursor()
    $foreground = [CornerNative]::GetForegroundWindow()
    $desktopFocused = $foreground -in @($script:cornerCards | ForEach-Object { $_.Handle }) -or $foreground -eq $script:hwnd -or [CornerNative]::ClassName($foreground) -in @('Progman','WorkerW','Shell_TrayWnd')
    # Keep the previous app/desktop context when the taskbar or our overlay takes focus.
    $class = [CornerNative]::ClassName($foreground)
    $desktopHandles = @($script:cornerCards | Where-Object { -not $_.Overlay } | ForEach-Object { $_.Handle })
    if ($class -in @('Progman','WorkerW') -or $foreground -eq $script:hwnd -or $foreground -in $desktopHandles) { $script:macDockDesktopContext = $true }
    elseif ($class -notin @('Shell_TrayWnd','Shell_SecondaryTrayWnd','#32768') -and $foreground -notin @($script:macDockEntry.Handle,$script:topBarEntry.Handle) -and $foreground -ne [IntPtr]::Zero) { $script:macDockDesktopContext = $false }
    foreach ($entry in $script:cornerCards) {
        if ($entry.Enabled -eq $false) { $entry.HoverStarted = $null; $entry.AppRevealed = $false; Set-CornerVisible $false $entry; continue }
        if ($entry.Dragging) { $entry.LastNear = [DateTime]::Now; continue }
        $placement = Get-WidgetPlacement $entry $work
        $entry.Window.Left = $placement.X; $entry.Window.Top = $placement.Y
        $point = $entry.Window.PointFromScreen([Windows.Point]::new($cursor.X, $cursor.Y))
        $near = Test-CornerProximity $point.X $point.Y $entry.Window.Width $entry.Window.Height
        $surfaceActive = $desktopFocused -or ($entry.Overlay -and -not [MacTaskNative]::IsFullscreen($foreground))
        if ($entry.Overlay -and -not $surfaceActive -and -not $entry.Configuring) { $entry.HoverStarted = $null; $entry.AppRevealed = $false; Set-CornerVisible $false $entry; continue }
        if ($entry.Name -eq 'MacDock') {
            # Cursor and Forms screen bounds are both device pixels: use the physical
            # screen edge, including the area occupied by the Windows taskbar.
            $bounds = [Windows.Forms.Screen]::PrimaryScreen.Bounds
            $edge = $cursor.X -ge $bounds.Left -and $cursor.X -lt $bounds.Right -and $cursor.Y -ge ($bounds.Bottom - 4) -and $cursor.Y -lt $bounds.Bottom
            $interacting = $entry.Configuring -or $entry.PickerOpen -or $entry.Window.ContextMenu.IsOpen
            $reveal = Test-MacDockReveal $entry ([bool]$script:macDockDesktopContext) $edge $near $interacting
            Set-CornerVisible $reveal $entry
            continue
        }
        if ($entry.Name -eq 'TopBar' -and -not $entry.Pinned -and -not $entry.Visible -and -not $entry.Configuring) {
            $edge = $point.X -ge 0 -and $point.X -le $entry.Window.Width -and $point.Y -ge 0 -and $point.Y -le 4
            $near = Test-TopBarDwell $entry $edge
        }
        $editing = $entry.Editable -and $foreground -eq $entry.Handle -and $entry.Window.IsKeyboardFocusWithin
        if ($entry.Window.ContextMenu.IsOpen -or $entry.Configuring -or $entry.PickerOpen -or $editing -or (($near -or $entry.Pinned) -and $surfaceActive)) {
            $entry.LastNear = [DateTime]::Now
            Set-CornerVisible $true $entry
        } elseif (-not $surfaceActive -or ([DateTime]::Now - $entry.LastNear).TotalMilliseconds -gt $(if ($script:widgetPreferences) { $script:widgetPreferences.hideDelay } else { 600 })) {
            if ($entry.Visible) { $entry.HoverStarted = $null }
            Set-CornerVisible $false $entry
        }
    }
    Update-MacDockTasks
    Update-TopMenuBar
    Update-Weather
    Update-SystemMonitor
    Update-Companions
    if ([DateTime]::Now -ge $script:cornerRefresh) {
        Update-CornerBattery
        if ($script:calendarDate -ne [DateTime]::Today.ToString('yyyy-MM-dd')) { Update-CornerCalendar }
        $script:cornerRefresh = [DateTime]::Now.AddSeconds(10)
    }
}

$cornerTemplate.FindName('PreviousMonth').Add_Click({ $script:calendarOffset--; Update-CornerCalendar })
$cornerTemplate.FindName('NextMonth').Add_Click({ $script:calendarOffset++; Update-CornerCalendar })
$calendarMonth.Add_Click({ $script:calendarOffset = 0; Update-CornerCalendar })
function Start-CornerWidgets {
    Update-CornerCalendar
    Update-CornerBattery
    Update-SystemMonitor
    foreach ($entry in $script:cornerCards) {
        $work = [Windows.SystemParameters]::WorkArea
        $placement = Get-WidgetPlacement $entry $work
        $entry.Window.Left = $placement.X; $entry.Window.Top = $placement.Y
        $entry.Handle = [Windows.Interop.WindowInteropHelper]::new($entry.Window).EnsureHandle()
        $style = [DesktopHost]::GetWindowLong($entry.Handle, -20)
        $style = $style -bor 0x80 -bor 0x20
        if (-not $entry.Editable) { $style = $style -bor 0x08000000 }
        [void][DesktopHost]::SetWindowLong($entry.Handle, -20, $style)
        $entry.Window.Show()
        if ($entry.Overlay) { $entry.Window.Topmost = $true } else { [void][DesktopHost]::Attach($entry.Handle) }
    }
    $script:cornerTimer = [Windows.Threading.DispatcherTimer]::new()
    $script:cornerTimer.Interval = [TimeSpan]::FromMilliseconds(80)
    $script:cornerTimer.Add_Tick({ Update-CornerHover })
    $script:cornerTimer.Start()
}

function Save-CornerPreview {
    Update-CornerCalendar
    Update-CornerBattery
    Update-SystemMonitor
    $bitmap = [Windows.Media.Imaging.RenderTargetBitmap]::new(2600,1500,192,192,[Windows.Media.PixelFormats]::Pbgra32)
    $visual = [Windows.Media.DrawingVisual]::new()
    $drawing = $visual.RenderOpen()
    foreach ($entry in $script:cornerCards) {
        $entry.Window.Opacity = 1
        $entry.Slide.Y = 0
        $entry.Slide.X = 0
        $entry.Window.Show()
        $entry.Window.UpdateLayout()
        $brush = [Windows.Media.VisualBrush]::new($entry.Window)
        $previewLeft = switch ($entry.Anchor) { 'TopBar' { 0 } 'BottomCenter' { (1300 - $entry.Window.Width) / 2 } 'LeftCenter' { 0 } 'RightCenter' { 1230 } 'TopCenter' { 474 } 'Right' { 1076 - ($entry.Offset - 10) } default { $entry.Offset - 10 } }
        $previewTop = if ($entry.Anchor -eq 'LeftCenter') { 260 } elseif ($entry.Anchor -in @('RightCenter','BottomLeft')) { 500 } elseif ($entry.TopOffset) { $entry.TopOffset } else { 0 }
        if ($entry.Name -ne 'TopBar') { $previewTop += 34 }
        if ($entry.Anchor -eq 'BottomCenter') { $previewTop = 640 }
        $drawing.DrawRectangle($brush, $null, [Windows.Rect]::new($previewLeft,$previewTop,$entry.Window.Width,$entry.Window.Height))
    }
    $drawing.Close()
    $bitmap.Render($visual)
    $encoder = [Windows.Media.Imaging.PngBitmapEncoder]::new()
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream = [IO.File]::Create((Join-Path $PSScriptRoot 'preview-corner.png'))
    try { $encoder.Save($stream) } finally { $stream.Dispose() }
    foreach ($entry in $script:cornerCards) { $entry.Window.Close() }
}
