. (Join-Path $PSScriptRoot 'MacTaskNative.ps1')
$script:macDockSettingsPath = Join-Path $PSScriptRoot 'mac-dock-settings.json'
$script:macDockPaths = @($script:dockPaths)
if (Test-Path -LiteralPath $macDockSettingsPath) {
    try {
        $savedMacDock = Get-Content -LiteralPath $macDockSettingsPath -Raw | ConvertFrom-Json
        if ($savedMacDock.shortcuts.Count -gt 0) { $script:macDockPaths = @($savedMacDock.shortcuts | ForEach-Object { [string]$_ }) }
    } catch { } # Keep usable defaults if the preferences file is invalid.
}
[xml]$macDockXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 Title="macOS taskbar" Width="544" Height="144" WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True"
 Background="Transparent" ShowInTaskbar="False" ShowActivated="False" Opacity="0" FontFamily="Segoe UI" Foreground="White">
 <Grid Margin="10,8,10,10">
  <Grid.RenderTransform><TranslateTransform x:Name="MacDockSlide" Y="20"/></Grid.RenderTransform>
  <Border x:Name="MacDockGlass" CornerRadius="24" BorderThickness="1" Padding="10,9" VerticalAlignment="Bottom" Height="76">
   <Border.Effect><DropShadowEffect BlurRadius="14" ShadowDepth="3" Opacity="0.3"/></Border.Effect>
  </Border>
  <ScrollViewer x:Name="MacDockScroll" Margin="12,0,12,2" HorizontalScrollBarVisibility="Hidden" VerticalScrollBarVisibility="Disabled" Padding="0,0,0,12"><StackPanel x:Name="MacDockButtons" Orientation="Horizontal" VerticalAlignment="Bottom" HorizontalAlignment="Center"/></ScrollViewer>
 </Grid>
</Window>
'@
$script:macDockWindow = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($macDockXaml))
$macDockWindow.Resources = $cornerTemplate.Resources
$macDockWindow.FindName('MacDockGlass').Background = $glassSource.Background.Clone()
$macDockWindow.FindName('MacDockGlass').BorderBrush = $glassSource.BorderBrush.Clone()
$script:macDockEntry = @{ Name = 'MacDock'; Window = $macDockWindow; Slide = $macDockWindow.FindName('MacDockSlide'); Handle = [IntPtr]::Zero; Visible = $false; LastNear = [DateTime]::MinValue; Offset = 4; Anchor = 'BottomCenter'; Configuring = $false }
$script:macDockEntry.Overlay = $true
$script:cornerCards += $macDockEntry
$script:macDockButtons = @()
$script:macDockDragStart = $null
$script:macDockSuppressClick = $false

function Save-MacDockSettings {
    try {
        @{ shortcuts = @($script:macDockPaths) } | ConvertTo-Json | Set-Content -LiteralPath $macDockSettingsPath -Encoding UTF8
        return $true
    } catch {
        [void][Windows.MessageBox]::Show('The shortcuts could not be saved. Please check the widget folder is writable.', 'macOS taskbar')
        return $false
    }
}

function Move-MacDockShortcut([int]$From, [int]$To) {
    if ($From -lt 0 -or $From -ge $script:macDockPaths.Count -or $To -lt 0 -or $To -ge $script:macDockPaths.Count -or $From -eq $To) { return }
    $before = @($script:macDockPaths)
    $ordered = [Collections.Generic.List[string]]::new()
    foreach ($path in $script:macDockPaths) { $ordered.Add($path) }
    $moving = $ordered[$From]
    $ordered.RemoveAt($From); $ordered.Insert($To, $moving)
    $script:macDockPaths = @($ordered.ToArray())
    if (-not (Save-MacDockSettings)) { $script:macDockPaths = $before }
    Update-MacDockButtons
}

function Set-MacDockHover($Button, [bool]$Hovered) {
    if ($Button.Content -isnot [Windows.Controls.Image]) { return }
    $duration = if ($script:widgetPreferences -and -not $script:widgetPreferences.motion) { 0 } else { 150 }
    $zoom = [Windows.Media.Animation.DoubleAnimation]::new($(if ($Hovered) { 2.0 } else { 1.0 }), [Windows.Duration]::new([TimeSpan]::FromMilliseconds($duration)))
    $zoom.EasingFunction = [Windows.Media.Animation.QuadraticEase]::new()
    $Button.Content.RenderTransform.BeginAnimation([Windows.Media.ScaleTransform]::ScaleXProperty, $zoom)
    $Button.Content.RenderTransform.BeginAnimation([Windows.Media.ScaleTransform]::ScaleYProperty, $zoom)
}

function Update-MacDockButtons {
    for ($slot = 0; $slot -lt $script:macDockPaths.Count; $slot++) {
        $button = $script:macDockButtons[$slot]
        $path = $script:macDockPaths[$slot]
        $button.Content = '+'
        $button.ToolTip = 'Choose app shortcut'
        $button.Visibility = if ($path) { 'Visible' } else { 'Collapsed' }
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
                $image.Width = 40; $image.Height = 40; $image.Source = $source
                $image.RenderTransformOrigin = [Windows.Point]::new(0.5,1)
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

function Add-MacDockShortcut([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf) -or [IO.Path]::GetExtension($Path) -notin @('.lnk','.url','.exe')) { return $false }
    if ($Path -in $script:macDockPaths) { return $false }
    $before = @($script:macDockPaths)
    $script:macDockPaths = @($script:macDockPaths) + $Path
    if (-not (Save-MacDockSettings)) { $script:macDockPaths = $before; return $false }
    New-MacDockButton ($script:macDockPaths.Count - 1)
    Update-MacDockButtons
    Expand-MacDockIcons
    $script:macTaskNextPoll = [DateTime]::MinValue
    return $true
}

function Select-MacDockShortcut([int]$Slot) {
    $script:macDockEntry.Configuring = $true
    try {
        $picker = [Microsoft.Win32.OpenFileDialog]::new()
        $picker.Title = if ($Slot -lt 0) { 'Add another app to the dock' } else { 'Choose an app shortcut for slot ' + ($Slot + 1) }
        $picker.Filter = 'Apps and shortcuts (*.lnk;*.url;*.exe)|*.lnk;*.url;*.exe'
        $picker.DereferenceLinks = $false
        $picker.InitialDirectory = [Environment]::GetFolderPath('Desktop')
        if ($picker.ShowDialog($macDockWindow)) {
            if ($Slot -lt 0) {
                if ($picker.FileName -in $script:macDockPaths) { [void][Windows.MessageBox]::Show('This app is already pinned to the dock.', 'Pinned apps') }
                else { [void](Add-MacDockShortcut $picker.FileName) }
                return
            }
            $previous = $script:macDockPaths[$Slot]
            $script:macDockPaths[$Slot] = $picker.FileName
            if (-not (Save-MacDockSettings)) { $script:macDockPaths[$Slot] = $previous }
            Update-MacDockButtons
        }
    } finally { $script:macDockEntry.Configuring = $false; $script:macDockEntry.LastNear = [DateTime]::Now }
}

[xml]$macDockStyleXaml = @'
<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" TargetType="Button">
 <Setter Property="Background" Value="Transparent"/><Setter Property="Foreground" Value="White"/><Setter Property="FontSize" Value="24"/><Setter Property="Cursor" Value="Hand"/>
 <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
  <Grid><Border x:Name="Tile" Background="{TemplateBinding Background}" CornerRadius="14"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><Border x:Name="WindowCount" Background="#DD244860" CornerRadius="8" HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,0,4,0" Padding="5,0" Visibility="Collapsed"><TextBlock x:Name="WindowCountText" FontSize="11" Foreground="White"/></Border><Rectangle x:Name="RunningDot" RadiusX="2" RadiusY="2" Width="22" Height="4" Fill="#E6FFFFFF" VerticalAlignment="Bottom" HorizontalAlignment="Center" Margin="0,0,0,0" Visibility="Collapsed"/></Grid>
  <ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Tile" Property="Background" Value="#25FFFFFF"/></Trigger><Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Tile" Property="BorderBrush" Value="#CCFFFFFF"/><Setter TargetName="Tile" Property="BorderThickness" Value="1"/></Trigger><Trigger Property="IsPressed" Value="True"><Setter TargetName="Tile" Property="Opacity" Value="0.65"/></Trigger></ControlTemplate.Triggers>
 </ControlTemplate></Setter.Value></Setter>
</Style>
'@
$script:macDockIconStyle = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($macDockStyleXaml))
$macDockMenu = [Windows.Controls.ContextMenu]::new()
function New-MacDockButton([int]$i) {
    $button = [Windows.Controls.Button]::new()
    $button.Style = $script:macDockIconStyle
    $button.Width = 56; $button.Height = 54; $button.Margin = [Windows.Thickness]::new(2,0,2,0)
    $button.Tag = $i
    [Windows.Controls.ToolTipService]::SetPlacement($button, 'Top')
    [Windows.Controls.ToolTipService]::SetInitialShowDelay($button, 350)
    [Windows.Controls.ToolTipService]::SetShowDuration($button, 5000)
    $button.AllowDrop = $true
    $button.Add_MouseEnter({ param($sender, $eventArgs) Set-MacDockHover $sender $true; Request-MacWindowPicker $sender })
    $button.Add_MouseLeave({ param($sender, $eventArgs) Set-MacDockHover $sender $false })
    $button.Add_PreviewMouseLeftButtonDown({
        param($sender, $eventArgs)
        $script:macDockSuppressClick = $false
        $script:macDockDragStart = $eventArgs.GetPosition($macDockWindow)
    })
    $button.Add_PreviewMouseMove({
        param($sender, $eventArgs)
        if ($eventArgs.LeftButton -ne 'Pressed' -or $null -eq $script:macDockDragStart) { return }
        $point = $eventArgs.GetPosition($macDockWindow)
        if ([Math]::Abs($point.Y - $script:macDockDragStart.Y) -lt [Windows.SystemParameters]::MinimumVerticalDragDistance -and [Math]::Abs($point.X - $script:macDockDragStart.X) -lt [Windows.SystemParameters]::MinimumHorizontalDragDistance) { return }
        $script:macDockDragStart = $null
        $script:macDockSuppressClick = $true
        $script:macDockEntry.Configuring = $true
        $sender.ReleaseMouseCapture()
        try {
            $data = [Windows.DataObject]::new('DesktopWidget.MacDockSlot', [int]$sender.Tag)
            [void][Windows.DragDrop]::DoDragDrop($sender, $data, [Windows.DragDropEffects]::Move)
        } finally {
            $script:macDockEntry.Configuring = $false
            $script:macDockEntry.LastNear = [DateTime]::Now
            foreach ($item in $script:macDockButtons) { $item.Background = [Windows.Media.Brushes]::Transparent }
        }
        $eventArgs.Handled = $true
    })
    $button.Add_DragOver({
        param($sender, $eventArgs)
        $eventArgs.Effects = [Windows.DragDropEffects]::None
        if ($script:macDockEntry.Configuring -and $eventArgs.Data.GetDataPresent('DesktopWidget.MacDockSlot')) {
            $eventArgs.Effects = [Windows.DragDropEffects]::Move
            $sender.Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#45FFFFFF')
        }
        $eventArgs.Handled = $true
    })
    $button.Add_DragLeave({ param($sender, $eventArgs) $sender.Background = [Windows.Media.Brushes]::Transparent })
    $button.Add_Drop({
        param($sender, $eventArgs)
        if ($script:macDockEntry.Configuring -and $eventArgs.Data.GetDataPresent('DesktopWidget.MacDockSlot')) {
            Move-MacDockShortcut ([int]$eventArgs.Data.GetData('DesktopWidget.MacDockSlot')) ([int]$sender.Tag)
        }
        $sender.Background = [Windows.Media.Brushes]::Transparent
        $eventArgs.Handled = $true
    })
    $button.Add_Click({
        param($sender, $eventArgs)
        if ($script:macDockSuppressClick) { $script:macDockSuppressClick = $false; return }
        $slot = [int]$sender.Tag
        if (Activate-MacDockSlot $slot) { return }
        $path = $script:macDockPaths[$slot]
        if (-not $path -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { Select-MacDockShortcut $slot; return }
        try {
            # Launch the shortcut itself to preserve arguments and working directory.
            $start = [Diagnostics.ProcessStartInfo]::new()
            $start.FileName = $path; $start.UseShellExecute = $true
            [void][Diagnostics.Process]::Start($start)
        } catch { [void][Windows.MessageBox]::Show('This shortcut could not be opened. Right-click the macDock to choose another.', 'macOS taskbar') }
    })
    if ($script:macDynamicPanel) { $macDockWindow.FindName('MacDockButtons').Children.Insert($i + 1,$button) }
    else { [void]$macDockWindow.FindName('MacDockButtons').Children.Add($button) }
    $script:macDockButtons += $button
    $item = [Windows.Controls.MenuItem]::new()
    $item.Header = 'Change app ' + ($i + 1) + '...'; $item.Tag = $i
    $item.Add_Click({ param($sender, $eventArgs) Select-MacDockShortcut ([int]$sender.Tag) })
    if ($script:macPinnedMenu) { [void]$script:macPinnedMenu.Items.Add($item) }
    else { [void]$macDockMenu.Items.Add($item) }
}
for ($i = 0; $i -lt $script:macDockPaths.Count; $i++) { New-MacDockButton $i }
$macDockWindow.ContextMenu = $macDockMenu
Update-MacDockButtons
$pinnedMenu = [Windows.Controls.MenuItem]::new(); $pinnedMenu.Header = 'Pinned apps'
$pinChoices = @($macDockMenu.Items)
$macDockMenu.Items.Clear()
foreach ($choice in $pinChoices) { [void]$pinnedMenu.Items.Add($choice) }
$script:macPinnedMenu = $pinnedMenu
$addApp = [Windows.Controls.MenuItem]::new(); $addApp.Header = 'Add another app...'
$addApp.Add_Click({ Select-MacDockShortcut -1 })
[void]$macDockMenu.Items.Add($addApp)
[void]$macDockMenu.Items.Add($pinnedMenu)

$script:macStartButton = [Windows.Controls.Button]::new()
$macStartButton.Style = $macDockIconStyle; $macStartButton.Width = 56; $macStartButton.Height = 54
$macStartButton.Margin = [Windows.Thickness]::new(2,0,2,0); $macStartButton.ToolTip = 'Windows Start'
$logo = [Windows.Shapes.Path]::new(); $logo.Data = [Windows.Media.Geometry]::Parse('M0,0 H15 V15 H0 Z M18,0 H33 V15 H18 Z M0,18 H15 V33 H0 Z M18,18 H33 V33 H18 Z')
$logo.Fill = [Windows.Media.BrushConverter]::new().ConvertFromString('#67C8FF'); $logo.Width = 33; $logo.Height = 33
$macStartButton.Content = $logo
[Windows.Automation.AutomationProperties]::SetName($macStartButton,'Open Windows Start')
$macStartButton.Add_Click({ [Windows.Forms.SendKeys]::SendWait('^{ESC}') })
$macDockWindow.FindName('MacDockButtons').Children.Insert(0,$macStartButton)
. (Join-Path $PSScriptRoot 'MacDockTasks.ps1')
