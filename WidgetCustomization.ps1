# Shared appearance, layout and a single settings window for the desktop suite.
. (Join-Path $PSScriptRoot 'WindowsTaskbar.ps1')
$script:customizationPath = Join-Path $PSScriptRoot 'widget-settings.json'
$script:widgetLabels = [ordered]@{ Calendar = 'Calendar'; Battery = 'Battery'; Weather = 'Weather'; Photo = 'Photo'; Dock = 'Left app dock'; MacDock = 'macOS taskbar'; TopBar = 'Top menu bar'; QuickNote = 'Quick note'; SystemMonitor = 'System monitor'; QuickFolders = 'Folder dock'; Daylight = 'Daylight window'; Pet = 'Codex pet' }
$script:widgetThemes = @{
    Glass = @('#996C819A','#80344259','#AA34465E')
    Midnight = @('#ED253247','#DD121C2C','#ED1C293D')
    Warm = @('#BB897A70','#AA49434A','#BB5F5556')
}
$script:widgetAccents = [ordered]@{ Ice = '#BCE9FF'; Mint = '#BDECD6'; Rose = '#F5CADC'; Gold = '#F4D7A4'; Lavender = '#D8CCFF' }
function New-WidgetPreferences {
    $cards = @{}
    foreach ($name in $script:widgetLabels.Keys) { $cards[$name] = @{ enabled = $true; pinned = $false; scale = 1.0; x = 0.0; y = 0.0 } }
    $cards.MacDock.pinned = $true
    $cards.TopBar.pinned = $false
    $cards.Pet.pinned = $true
    $cards.Daylight.pinned = $true
    return @{ hideWindowsTaskbar = $false; dockWidth = 96; theme = 'Glass'; accent = 'Ice'; glassOpacity = 0.85; motion = $true; hideDelay = 600; clockStyle = $script:selectedStyle; clockColor = $script:selectedColor; clockScale = 1.0; clockX = 0.0; clockY = 0.0; timeFormat = '24-hour'; dateFormat = 'd/M/yyyy'; showSeconds = $false; showMedia = $true; photoFit = 'Fill'; noteFont = 12; weatherUnits = 'Celsius'; widgets = $cards }
}
function ConvertTo-WidgetPreferences($Raw) {
    $result = New-WidgetPreferences
    foreach ($key in @('theme','accent','timeFormat','dateFormat','photoFit','clockStyle','clockColor','weatherUnits')) {
        $allowed = switch ($key) {
            theme { @('Glass','Midnight','Warm') }; accent { @($script:widgetAccents.Keys) }
            timeFormat { @('24-hour','12-hour') }; dateFormat { @('d/M/yyyy','ddd, d MMM','MMMM d, yyyy','yyyy-MM-dd') }; photoFit { @('Fill','Fit') }
            clockStyle { @($styles.Keys) }; clockColor { @($colors.Keys) }; weatherUnits { @('Celsius','Fahrenheit') }
        }
        if ($Raw.$key -in $allowed) { $result[$key] = [string]$Raw.$key }
    }
    foreach ($key in @('motion','showSeconds','showMedia','hideWindowsTaskbar')) { if ($Raw.$key -is [bool]) { $result[$key] = $Raw.$key } }
    $ranges = @{ dockWidth = @(50,100); glassOpacity = @(0.3,1); hideDelay = @(100,3000); clockScale = @(0.65,1.5); clockX = @(-10000,10000); clockY = @(-10000,10000); noteFont = @(10,20) }
    foreach ($key in $ranges.Keys) {
        $number = 0.0
        if ($null -ne $Raw.$key -and [double]::TryParse([string]$Raw.$key, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$number) -and -not [double]::IsNaN($number) -and -not [double]::IsInfinity($number)) {
            $result[$key] = [Math]::Max($ranges[$key][0], [Math]::Min($ranges[$key][1], $number))
        }
    }
    foreach ($name in $script:widgetLabels.Keys) {
        $savedCard = $Raw.widgets.$name
        foreach ($key in @('enabled','pinned')) { if ($savedCard.$key -is [bool]) { $result.widgets[$name][$key] = $savedCard.$key } }
        foreach ($key in @('scale','x','y')) {
            $number = 0.0
            if ($null -ne $savedCard.$key -and [double]::TryParse([string]$savedCard.$key, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$number) -and -not [double]::IsNaN($number) -and -not [double]::IsInfinity($number)) {
                $min = if ($key -eq 'scale') { 0.7 } else { -10000 }; $max = if ($key -eq 'scale') { 1.5 } else { 10000 }
                $result.widgets[$name][$key] = [Math]::Max($min, [Math]::Min($max,$number))
            }
        }
    }
    return $result
}
$script:widgetPreferences = New-WidgetPreferences
if (-not $Preview -and (Test-Path -LiteralPath $script:customizationPath)) {
    try { $script:widgetPreferences = ConvertTo-WidgetPreferences (Get-Content -LiteralPath $script:customizationPath -Raw | ConvertFrom-Json) } catch { }
}
function Save-WidgetPreferences($Preferences = $script:widgetPreferences) {
    $temporary = $script:customizationPath + '.tmp'
    try {
        [IO.File]::WriteAllText($temporary, ($Preferences | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
        if ([IO.File]::Exists($script:customizationPath)) { [IO.File]::Replace($temporary, $script:customizationPath, [System.Management.Automation.Language.NullString]::Value) }
        else { [IO.File]::Move($temporary, $script:customizationPath) }
    } finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
}
function Get-WidgetTimeFormat {
    if ($script:widgetPreferences.timeFormat -eq '12-hour') {
        if ($script:widgetPreferences.showSeconds) { return 'h:mm:ss tt' }; return 'h:mm tt'
    }
    if ($script:widgetPreferences.showSeconds) { return 'HH:mm:ss' }; return 'HH:mm'
}
function Set-WidgetScale($Entry, [double]$Scale) {
    if ($Entry.Name -eq 'MacDock') {
        $Entry.Window.Width = [Windows.SystemParameters]::WorkArea.Width * $script:widgetPreferences.dockWidth / 100
        $Entry.Window.Height = $Entry.BaseHeight * $Scale
        $Entry.Window.FindName('MacDockGlass').Height = 76 * $Scale
        $Entry.Window.FindName('MacDockButtons').LayoutTransform = [Windows.Media.ScaleTransform]::new($Scale,$Scale)
        return
    }
    if ($Entry.Name -eq 'TopBar') {
        $Entry.Window.Width = [Windows.SystemParameters]::WorkArea.Width
        $Entry.Window.Height = $Entry.BaseHeight * $Scale
        return
    }
    $Entry.Window.Width = $Entry.BaseWidth * $Scale
    $Entry.Window.Height = $Entry.BaseHeight * $Scale
    if ($Entry.Name -eq 'MacDock' -and $Entry.Window.Width -gt [Windows.SystemParameters]::WorkArea.Width) {
        $fit = [Windows.SystemParameters]::WorkArea.Width / $Entry.BaseWidth
        $Entry.Window.Width = $Entry.BaseWidth * $fit; $Entry.Window.Height = $Entry.BaseHeight * $fit
    }
}
function Apply-WidgetPreferences {
    Update-WindowsTaskbar
    $p = $script:widgetPreferences
    $script:selectedStyle = $p.clockStyle; $script:selectedColor = $p.clockColor
    $theme = $script:widgetThemes[$p.theme]
    $accent = [Windows.Media.BrushConverter]::new().ConvertFromString($script:widgetAccents[$p.accent])
    foreach ($card in $script:cornerCards) {
        $choice = $p.widgets[$card.Name]
        $card.Enabled = $choice.enabled; $card.Pinned = $choice.pinned
        Set-WidgetScale $card $choice.scale
        $background = [Windows.Media.LinearGradientBrush]::new()
        $background.StartPoint = [Windows.Point]::new(0,0); $background.EndPoint = [Windows.Point]::new(0.8,1)
        for ($i = 0; $i -lt 3; $i++) { $background.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString($theme[$i]), $i / 2.0)) }
        $background.Opacity = $p.glassOpacity
        $card.Glass.Background = $background
        $rim = [Windows.Media.LinearGradientBrush]::new()
        $rim.StartPoint = [Windows.Point]::new(0,0); $rim.EndPoint = [Windows.Point]::new(1,1)
        $rim.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString('#A0FFFFFF'),0))
        $rim.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString('#20FFFFFF'),0.55))
        $rim.GradientStops.Add([Windows.Media.GradientStop]::new($accent.Color,1))
        $rim.Opacity = 0.7
        $card.Glass.BorderBrush = $rim
        if ($card.Handle -ne [IntPtr]::Zero -and -not $card.Enabled) { Set-CornerVisible $false $card }
        if ($card.Handle -ne [IntPtr]::Zero) {
            $position = Get-WidgetPlacement $card
            $card.Window.Left = $position.X; $card.Window.Top = $position.Y
        }
    }
    foreach ($metric in $script:monitorMetrics.Values) { $metric.Bar.Background = $accent }
    $weatherIcon.Foreground = $accent
    if ($script:weatherData) {
        Set-WeatherData $script:weatherData
        if ($script:weatherError) { $weatherUpdated.Text = 'Offline | last data {0:HH:mm}' -f $script:weatherLastUpdated }
    }
    $noteEditor.SelectionBrush = $accent.Clone(); $noteEditor.SelectionBrush.Opacity = 0.45
    $noteEditor.FontSize = $p.noteFont
    $fill = $photoWindow.FindName('PhotoSurface').Fill
    if ($fill -is [Windows.Media.ImageBrush]) {
        $fill = $fill.Clone(); $fill.Stretch = if ($p.photoFit -eq 'Fit') { 'Uniform' } else { 'UniformToFill' }
        $photoWindow.FindName('PhotoSurface').Fill = $fill
    }
    $window.Width = 720 * $p.clockScale; $window.Height = 370 * $p.clockScale
    $mediaPanel.Visibility = if ($p.showMedia) { 'Visible' } else { 'Collapsed' }
    Update-Clock
    Update-CornerCalendar
    Update-CornerBattery
    Center-Widget
}

# A consistent dark menu and tooltip treatment across every card.
[xml]$widgetResourcesXaml = @'
<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
 <Style TargetType="ContextMenu">
  <Setter Property="Background" Value="#FA202632"/><Setter Property="Foreground" Value="#F0F5FF"/>
  <Setter Property="BorderBrush" Value="#52647288"/><Setter Property="BorderThickness" Value="1"/><Setter Property="Padding" Value="7"/>
  <Setter Property="FontFamily" Value="Segoe UI"/><Setter Property="FontSize" Value="13"/>
  <Setter Property="HasDropShadow" Value="False"/>
  <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ContextMenu">
   <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="13" Padding="{TemplateBinding Padding}" MinWidth="235">
    <ScrollViewer CanContentScroll="True" VerticalScrollBarVisibility="Auto" MaxHeight="640"><ItemsPresenter KeyboardNavigation.DirectionalNavigation="Cycle"/></ScrollViewer>
   </Border>
  </ControlTemplate></Setter.Value></Setter>
 </Style>
 <Style TargetType="Separator"><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Separator"><Border Height="1" Background="#304F5A6D" Margin="12,6"/></ControlTemplate></Setter.Value></Setter></Style>
 <Style TargetType="MenuItem">
  <Setter Property="Padding" Value="10,10"/><Setter Property="Foreground" Value="#F0F5FF"/>
  <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="MenuItem">
   <Grid>
    <Border x:Name="Surface" CornerRadius="6" Background="Transparent" Padding="{TemplateBinding Padding}">
     <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="18"/><ColumnDefinition Width="*"/><ColumnDefinition Width="16"/></Grid.ColumnDefinitions>
      <TextBlock x:Name="Check" Text="&#x2713;" Visibility="Hidden"/>
      <ContentPresenter Grid.Column="1" ContentSource="Header" RecognizesAccessKey="True"/>
      <TextBlock x:Name="Arrow" Grid.Column="2" Text="&#x203A;" Visibility="Hidden" HorizontalAlignment="Right"/>
     </Grid>
    </Border>
    <Popup x:Name="PART_Popup" IsOpen="{Binding IsSubmenuOpen, RelativeSource={RelativeSource TemplatedParent}}" Placement="Right" AllowsTransparency="True" Focusable="False">
     <Border Background="#FA202632" BorderBrush="#52647288" BorderThickness="1" CornerRadius="12" Padding="7"><ScrollViewer VerticalScrollBarVisibility="Auto" MaxHeight="640"><StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Cycle"/></ScrollViewer></Border>
    </Popup>
   </Grid>
   <ControlTemplate.Triggers>
    <Trigger Property="IsHighlighted" Value="True"><Setter TargetName="Surface" Property="Background" Value="#665B4C96"/></Trigger>
    <Trigger Property="IsChecked" Value="True"><Setter TargetName="Check" Property="Visibility" Value="Visible"/></Trigger>
    <Trigger Property="HasItems" Value="True"><Setter TargetName="Arrow" Property="Visibility" Value="Visible"/></Trigger>
    <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.4"/></Trigger>
   </ControlTemplate.Triggers>
  </ControlTemplate></Setter.Value></Setter>
 </Style>
 <Style TargetType="ToolTip"><Setter Property="Background" Value="#F2223043"/><Setter Property="Foreground" Value="#F0F5FF"/><Setter Property="BorderBrush" Value="#506C86A0"/><Setter Property="Padding" Value="10,7"/></Style>
</ResourceDictionary>
'@
$script:widgetResources = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($widgetResourcesXaml))

function Add-WidgetDrag($Target, [string]$Name) {
    $Target.Tag = $Name
    $Target.Add_PreviewMouseLeftButtonDown({
        param($sender,$eventArgs)
        if (-not ([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Control)) { return }
        $eventArgs.Handled = $true
        $cursor = [CornerNative]::Cursor()
        $script:widgetDrag = @{ Window = $sender; Name = [string]$sender.Tag; X = $cursor.X; Y = $cursor.Y; Left = $sender.Left; Top = $sender.Top }
        if ($sender.Tag -ne 'Clock') { ($script:cornerCards | Where-Object Name -eq $sender.Tag).Dragging = $true }
        [void]$sender.CaptureMouse()
    })
    $Target.Add_PreviewMouseMove({
        param($sender,$eventArgs)
        if (-not $script:widgetDrag -or $script:widgetDrag.Window -ne $sender) { return }
        $cursor = [CornerNative]::Cursor()
        $transform = [Windows.PresentationSource]::FromVisual($sender).CompositionTarget.TransformFromDevice
        $delta = $transform.Transform([Windows.Vector]::new($cursor.X - $script:widgetDrag.X, $cursor.Y - $script:widgetDrag.Y))
        $work = [Windows.SystemParameters]::WorkArea
        $sender.Left = [Math]::Max($work.Left,[Math]::Min($work.Right - $sender.Width,$script:widgetDrag.Left + $delta.X))
        $sender.Top = [Math]::Max($work.Top,[Math]::Min($work.Bottom - $sender.Height,$script:widgetDrag.Top + $delta.Y))
        $eventArgs.Handled = $true
    })
    $Target.Add_PreviewMouseLeftButtonUp({
        param($sender,$eventArgs)
        if (-not $script:widgetDrag -or $script:widgetDrag.Window -ne $sender) { return }
        $eventArgs.Handled = $true
        Complete-WidgetDrag
    })
    $Target.Add_LostMouseCapture({ if ($script:widgetDrag) { Complete-WidgetDrag } })
}
function Complete-WidgetDrag {
    $drag = $script:widgetDrag
    if (-not $drag) { return }
    $script:widgetDrag = $null
    $dx = $drag.Window.Left - $drag.Left; $dy = $drag.Window.Top - $drag.Top
    if ($drag.Name -eq 'Clock') {
        $script:widgetPreferences.clockX += $dx; $script:widgetPreferences.clockY += $dy
    } else {
        $choice = $script:widgetPreferences.widgets[$drag.Name]; $choice.x += $dx; $choice.y += $dy
        $card = $script:cornerCards | Where-Object Name -eq $drag.Name
        $card.Dragging = $false; $card.LastNear = [DateTime]::Now
    }
    $drag.Window.ReleaseMouseCapture()
    try { if (-not $Preview) { Save-WidgetPreferences } }
    catch { [void][Windows.MessageBox]::Show('The position changed, but could not be saved. Check the widget folder is writable.', 'Widget settings') }
}
function Initialize-WidgetCustomization {
    $glassNames = @{ Calendar = 'CalendarCard'; Battery = 'BatteryCard'; Weather = 'WeatherGlass'; Photo = 'PhotoGlass'; Dock = 'DockGlass'; MacDock = 'MacDockGlass'; TopBar = 'TopBarGlass'; QuickNote = 'NoteGlass'; SystemMonitor = 'MonitorGlass'; QuickFolders = 'FolderGlass'; Daylight = 'DaylightGlass'; Pet = 'PetGlass' }
    foreach ($card in $script:cornerCards) {
        $card.BaseWidth = $card.Window.Width; $card.BaseHeight = $card.Window.Height
        $card.Enabled = $true; $card.Pinned = $false
        $card.Glass = if ($card.Name -in @('Calendar','Battery')) { $cornerTemplate.FindName($glassNames[$card.Name]) } else { $card.Window.FindName($glassNames[$card.Name]) }
        $content = $card.Window.Content; $card.Window.Content = $null
        $content.Width = $card.BaseWidth - $content.Margin.Left - $content.Margin.Right
        $content.Height = $card.BaseHeight - $content.Margin.Top - $content.Margin.Bottom
        $view = [Windows.Controls.Viewbox]::new(); $view.Stretch = 'Fill'; $view.Child = $content
        $card.Window.Content = $view
        if ($card.Name -in @('TopBar','MacDock')) {
            $view.Child = $null; $content.Width = [double]::NaN; $content.Height = [double]::NaN
            $card.Window.Content = $content
        }
        $card.Window.Resources.MergedDictionaries.Add($script:widgetResources)
        if (-not $card.Window.ContextMenu) { $card.Window.ContextMenu = [Windows.Controls.ContextMenu]::new() }
        $context = $card.Window.ContextMenu
        $context.Resources.MergedDictionaries.Add($script:widgetResources)
        if ($context.Items.Count) { [void]$context.Items.Add([Windows.Controls.Separator]::new()) }
        $pin = [Windows.Controls.MenuItem]::new(); $pin.Header = if ($card.Name -eq 'MacDock') { 'Keep visible on desktop' } elseif ($card.Overlay) { 'Keep visible over apps' } else { 'Keep visible on desktop' }; $pin.IsCheckable = $true; $pin.Tag = $card.Name
        $pin.Add_Click({
            param($sender,$eventArgs)
            $choice = $script:widgetPreferences.widgets[[string]$sender.Tag]; $before = $choice.pinned; $choice.pinned = [bool]$sender.IsChecked
            try { Save-WidgetPreferences; Apply-WidgetPreferences }
            catch { $choice.pinned = $before; $sender.IsChecked = $before; [void][Windows.MessageBox]::Show('Could not save your preference.', 'Widget settings') }
        })
        $card.PinMenu = $pin; [void]$context.Items.Add($pin)
        $context.Add_Opened({ foreach ($entry in $script:cornerCards) { $entry.PinMenu.IsChecked = $script:widgetPreferences.widgets[$entry.Name].pinned } })
        $settingsItem = [Windows.Controls.MenuItem]::new(); $settingsItem.Header = 'Customize widgets...'; $settingsItem.Add_Click({ Show-WidgetSettings })
        [void]$context.Items.Add($settingsItem)
        if ($card.Name -ne 'TopBar') { Add-WidgetDrag $card.Window $card.Name }
    }
    $clockContent = $window.Content; $window.Content = $null; $clockContent.Width = 720; $clockContent.Height = 370
    $clockView = [Windows.Controls.Viewbox]::new(); $clockView.Stretch = 'Fill'; $clockView.Child = $clockContent; $window.Content = $clockView
    $window.Resources.MergedDictionaries.Add($script:widgetResources)
    $menu.Resources.MergedDictionaries.Add($script:widgetResources)
    $settingsItem = [Windows.Controls.MenuItem]::new(); $settingsItem.Header = 'Customize widgets...'; $settingsItem.Add_Click({ Show-WidgetSettings })
    $menu.Items.Insert(0,$settingsItem)
    Add-WidgetDrag $window 'Clock'
    Apply-WidgetPreferences
}
