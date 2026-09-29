Add-Type -Path (Join-Path $PSScriptRoot 'TopBarNative.cs')
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[Windows.Devices.Radios.Radio,Windows.System.Devices,ContentType=WindowsRuntime] | Out-Null
[Windows.Devices.Radios.RadioAccessStatus,Windows.System.Devices,ContentType=WindowsRuntime] | Out-Null
[Windows.Devices.Radios.RadioState,Windows.System.Devices,ContentType=WindowsRuntime] | Out-Null
$script:topPanel = [Windows.Controls.Primitives.Popup]::new()
$topPanel.AllowsTransparency = $true; $topPanel.StaysOpen = $false; $topPanel.Placement = 'Bottom'; $topPanel.VerticalOffset = 7
$script:topPanelSurface = [Windows.Controls.Border]::new()
$topPanelSurface.Width = 320; $topPanelSurface.CornerRadius = [Windows.CornerRadius]::new(22)
$topPanelSurface.Padding = [Windows.Thickness]::new(15)
function Set-TopGlassMaterial([bool]$Blurred) {
    $material = [Windows.Media.LinearGradientBrush]::new()
    $material.StartPoint = [Windows.Point]::new(0,0); $material.EndPoint = [Windows.Point]::new(0.85,1)
    $colors = if ($Blurred) { @('#944D5766','#B42A3342','#AD303845') } else { @('#FF444E5C','#FF273140','#FF323B49') }
    for($i=0;$i -lt 3;$i++){ $material.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString($colors[$i]),$i/2.0)) }
    $script:topPanelSurface.Background = $material
}
Set-TopGlassMaterial $false
$rim = [Windows.Media.LinearGradientBrush]::new()
$rim.StartPoint = [Windows.Point]::new(0,0); $rim.EndPoint = [Windows.Point]::new(1,1)
$rim.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString('#B9FFFFFF'),0))
$rim.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString('#22445368'),0.5))
$rim.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString('#667F91AB'),1))
$topPanelSurface.BorderBrush = $rim
$topPanelSurface.UseLayoutRounding = $true
$topPanelSurface.SnapsToDevicePixels = $true
$topPanelSurface.BorderThickness = [Windows.Thickness]::new(1)
$script:topPanelItems = [Windows.Controls.StackPanel]::new()
$scroll = [Windows.Controls.ScrollViewer]::new(); $scroll.VerticalScrollBarVisibility = 'Auto'; $scroll.MaxHeight = [Math]::Max(240,[Windows.SystemParameters]::WorkArea.Height - 80)
$scroll.Content = $topPanelItems; $topPanelSurface.Child = $scroll; $topPanel.Child = $topPanelSurface
$topPanel.Add_Opened({
    $script:topBarEntry.Configuring = $true
    $source = [Windows.PresentationSource]::FromVisual($script:topPanelSurface)
    $script:topGlassActive = $false
    if (-not $Preview -and -not [Windows.SystemParameters]::HighContrast -and $source -is [Windows.Interop.HwndSource]) {
        $radius = [int](22 * $source.CompositionTarget.TransformToDevice.M11)
        $script:topGlassActive = [MenuGlass]::Apply($source.Handle,$radius)
    }
    Set-TopGlassMaterial $script:topGlassActive
    # Focus the panel itself; keyboard navigation remains available without a selected tile on open.
    [void]$script:topPanelSurface.Focus()
})
$topPanelSurface.Focusable = $true
$topPanelSurface.Add_SizeChanged({
    if ($script:topGlassActive) {
        $source=[Windows.PresentationSource]::FromVisual($script:topPanelSurface)
        if($source -is [Windows.Interop.HwndSource]){[MenuGlass]::Round($source.Handle,[int](22*$source.CompositionTarget.TransformToDevice.M11))}
    }
})
$topPanel.Add_Closed({ $script:topBarEntry.Configuring = $false; $script:topBarEntry.LastNear = [DateTime]::Now })
$topPanelSurface.Add_PreviewKeyDown({ param($sender,$e) if ($e.Key -eq 'Escape') { $script:topPanel.IsOpen = $false; $e.Handled = $true } })
$topBarWindow.Add_Closed({ $script:topPanel.IsOpen = $false })

[xml]$panelButtonXaml = @'
<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" TargetType="Button">
 <Setter Property="Foreground" Value="White"/><Setter Property="Background" Value="#0CFFFFFF"/><Setter Property="FontSize" Value="13"/><Setter Property="FontFamily" Value="Segoe UI"/><Setter Property="Cursor" Value="Hand"/><Setter Property="HorizontalContentAlignment" Value="Left"/><Setter Property="Padding" Value="12,8"/><Setter Property="Margin" Value="0,2"/>
 <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="Tile" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}" BorderBrush="#20FFFFFF" BorderThickness="1" CornerRadius="12"><ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Tile" Property="Background" Value="#26FFFFFF"/></Trigger><Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Tile" Property="BorderBrush" Value="#A6CFFF"/></Trigger><Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.45"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
</Style>
'@
$script:topPanelButtonStyle = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($panelButtonXaml))
[xml]$volumeStyleXaml = @"
<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" TargetType="Slider">
 <Setter Property="Height" Value="30"/><Setter Property="IsMoveToPointEnabled" Value="True"/><Setter Property="SmallChange" Value="1"/><Setter Property="LargeChange" Value="5"/>
 <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Slider">
  <Grid SnapsToDevicePixels="True">
   <ProgressBar x:Name="VolumeFill" IsHitTestVisible="False" Minimum="{TemplateBinding Minimum}" Maximum="{TemplateBinding Maximum}" Value="{Binding Value,RelativeSource={RelativeSource TemplatedParent}}">
    <ProgressBar.Template><ControlTemplate TargetType="ProgressBar"><Grid>
     <Border x:Name="PART_Track" CornerRadius="15" Background="#554D596B" BorderBrush="#25FFFFFF" BorderThickness="1"/>
     <Border x:Name="PART_Indicator" HorizontalAlignment="Left" CornerRadius="15"><Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="0,1"><GradientStop Color="#FFFFFFFF" Offset="0"/><GradientStop Color="#FFD9E4F0" Offset="1"/></LinearGradientBrush></Border.Background></Border>
    </Grid></ControlTemplate></ProgressBar.Template>
   </ProgressBar>
   <Track x:Name="PART_Track" Minimum="{TemplateBinding Minimum}" Maximum="{TemplateBinding Maximum}" Value="{Binding Value,RelativeSource={RelativeSource TemplatedParent},Mode=TwoWay}" IsDirectionReversed="False">
    <Track.DecreaseRepeatButton><RepeatButton Command="Slider.DecreaseLarge" Focusable="False"><RepeatButton.Template><ControlTemplate TargetType="RepeatButton"><Border Background="Transparent"/></ControlTemplate></RepeatButton.Template></RepeatButton></Track.DecreaseRepeatButton>
    <Track.Thumb><Thumb Width="16"><Thumb.Template><ControlTemplate TargetType="Thumb"><Grid Background="Transparent"><Border Width="3" Height="12" CornerRadius="1.5" Background="#66333E4F"/></Grid></ControlTemplate></Thumb.Template></Thumb></Track.Thumb>
    <Track.IncreaseRepeatButton><RepeatButton Command="Slider.IncreaseLarge" Focusable="False"><RepeatButton.Template><ControlTemplate TargetType="RepeatButton"><Border Background="Transparent"/></ControlTemplate></RepeatButton.Template></RepeatButton></Track.IncreaseRepeatButton>
   </Track>
  </Grid>
  <ControlTemplate.Triggers><Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.4"/></Trigger></ControlTemplate.Triggers>
 </ControlTemplate></Setter.Value></Setter>
</Style>
"@
$script:topVolumeStyle = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($volumeStyleXaml))
function Set-TopRadioVisual {
    $on = $script:topRadio.State.ToString() -eq 'On'
    $grid = [Windows.Controls.DockPanel]::new()
    $pill = [Windows.Controls.Border]::new(); $pill.Width = 36; $pill.Height = 22; $pill.CornerRadius = [Windows.CornerRadius]::new(11)
    $pill.Background = [Windows.Media.BrushConverter]::new().ConvertFromString($(if($on){'#3478F6'}else{'#777D87'}))
    [Windows.Controls.DockPanel]::SetDock($pill,'Right')
    $dot = [Windows.Shapes.Ellipse]::new(); $dot.Width=18; $dot.Height=18; $dot.Fill=[Windows.Media.Brushes]::White; $dot.Margin=[Windows.Thickness]::new(2)
    $dot.HorizontalAlignment=if($on){'Right'}else{'Left'}; $pill.Child=$dot; [void]$grid.Children.Add($pill)
    $label=[Windows.Controls.TextBlock]::new(); $label.Text=if($on){'On'}else{'Off'}; $label.VerticalAlignment='Center'; [void]$grid.Children.Add($label)
    $script:topRadioButton.Content=$grid
    [Windows.Automation.AutomationProperties]::SetName($script:topRadioButton,($script:topRadioKind + ' ' + $label.Text + ', toggle'))
}
function Add-TopTile($Panel,[string]$Glyph,[string]$Label,[string]$Action) {
    $b=[Windows.Controls.Button]::new(); $b.Style=$script:topPanelButtonStyle; $b.Tag=$Action; $b.Margin=[Windows.Thickness]::new(3); $b.Width=136; $b.Height=68
    $stack=[Windows.Controls.StackPanel]::new()
    $icon=[Windows.Controls.TextBlock]::new();$icon.FontFamily='Segoe MDL2 Assets';$icon.Text=$Glyph;$icon.FontSize=18;$icon.Margin=[Windows.Thickness]::new(0,0,0,7)
    $text=[Windows.Controls.TextBlock]::new();$text.Text=$Label;$text.FontSize=12
    [void]$stack.Children.Add($icon);[void]$stack.Children.Add($text);$b.Content=$stack
    $b.Add_Click({param($sender,$e) Invoke-TopAction ([string]$sender.Tag)})
    [void]$Panel.Children.Add($b)
}
function Add-TopText([string]$Text,[int]$Size = 12,[string]$Color = '#BFC5CF') {
    $label = [Windows.Controls.TextBlock]::new(); $label.Text = $Text; $label.FontFamily = 'Segoe UI'; $label.FontSize = $Size
    $label.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString($Color); $label.Margin = [Windows.Thickness]::new(5,6,5,6); $label.TextWrapping = 'Wrap'
    if ($Size -ge 17) { $label.FontWeight = 'SemiBold'; $label.Margin = [Windows.Thickness]::new(5,1,5,12) }
    [void]$script:topPanelItems.Children.Add($label)
    return $label
}
function Add-TopAction([string]$Label,[string]$Action) {
    $button = [Windows.Controls.Button]::new(); $button.Style = $script:topPanelButtonStyle; $button.Content = $Label; $button.Tag = $Action
    $button.Add_Click({ param($sender,$e) Invoke-TopAction ([string]$sender.Tag) })
    [void]$script:topPanelItems.Children.Add($button)
    return $button
}
function Invoke-TopAction([string]$Action) {
    if ($Action -like 'panel:*') { Show-TopPanel $Action.Substring(6) $script:topPanel.PlacementTarget; return }
    $script:topPanel.IsOpen = $false
    if ($Action -eq 'customize') { Show-WidgetSettings; return }
    try { Start-Process explorer.exe -ArgumentList $Action } catch { [void][Windows.MessageBox]::Show('This setting could not be opened.','Menu bar') }
}
function Add-TopDivider {
    $line = [Windows.Controls.Border]::new(); $line.Height = 1; $line.Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#25FFFFFF'); $line.Margin = [Windows.Thickness]::new(5,6,5,6)
    [void]$script:topPanelItems.Children.Add($line)
}
function Add-TopVolume {
    $card = [Windows.Controls.Border]::new(); $card.CornerRadius = [Windows.CornerRadius]::new(15); $card.Padding = [Windows.Thickness]::new(10)
    $card.Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#14FFFFFF'); $card.BorderBrush = [Windows.Media.BrushConverter]::new().ConvertFromString('#22FFFFFF'); $card.BorderThickness = [Windows.Thickness]::new(1); $card.Margin = [Windows.Thickness]::new(2,8,2,4)
    $body = [Windows.Controls.StackPanel]::new(); $card.Child = $body
    $header = [Windows.Controls.DockPanel]::new(); $header.LastChildFill = $true
    $script:topMute = [Windows.Controls.Button]::new(); $topMute.Style = $script:topPanelButtonStyle; $topMute.FontSize = 11; $topMute.Padding = [Windows.Thickness]::new(9,4,9,4); $topMute.ToolTip='Mute or unmute system audio'
    [Windows.Controls.DockPanel]::SetDock($topMute,'Right'); [void]$header.Children.Add($topMute)
    $script:topVolumeLabel = [Windows.Controls.TextBlock]::new(); $topVolumeLabel.Foreground = [Windows.Media.Brushes]::White; $topVolumeLabel.FontFamily='Segoe UI'; $topVolumeLabel.FontSize=13; $topVolumeLabel.FontWeight='SemiBold'; $topVolumeLabel.VerticalAlignment='Center'; $topVolumeLabel.Margin=[Windows.Thickness]::new(3,0,0,0)
    [void]$header.Children.Add($topVolumeLabel); [void]$body.Children.Add($header)
    $script:topVolume = [Windows.Controls.Slider]::new(); $topVolume.Style = $script:topVolumeStyle; $topVolume.Minimum = 0; $topVolume.Maximum = 100; $topVolume.Margin = [Windows.Thickness]::new(2,9,2,2)
    [Windows.Automation.AutomationProperties]::SetName($topVolume,'System output volume')
    try { $topVolume.Value = [MenuAudio]::Volume()*100; $topVolumeLabel.Text = 'Sound   ' + [Math]::Round($topVolume.Value) + '%'; $available = $true } catch { $topVolume.IsEnabled = $false; $topVolumeLabel.Text = 'Audio unavailable'; $available = $false }
    $topVolume.Add_ValueChanged({
        param($sender,$e)
        if ($script:topPanelUpdating) { return }
        try { [MenuAudio]::SetVolume([float]($sender.Value/100)); $script:topVolumeLabel.Text = 'Sound   ' + [Math]::Round($sender.Value) + '%' } catch { $script:topVolumeLabel.Text = 'Could not change volume' }
    })
    [void]$body.Children.Add($topVolume)
    $topMute.IsEnabled = $available
    $topMute.Content = if ($available -and [MenuAudio]::Muted()) { 'Unmute' } else { 'Mute' }
    $topMute.Add_Click({ try { [MenuAudio]::SetMuted(-not [MenuAudio]::Muted()); $script:topMute.Content = if ([MenuAudio]::Muted()) { 'Unmute' } else { 'Mute' } } catch { $script:topMute.Content = 'Unavailable' } })
    [void]$script:topPanelItems.Children.Add($card)
}
function Add-TopRadio([string]$Kind) {
    $script:topRadioKind = $Kind
    $script:topRadioButton = [Windows.Controls.Button]::new(); $topRadioButton.Style = $script:topPanelButtonStyle; $topRadioButton.HorizontalContentAlignment = 'Stretch'; $topRadioButton.Content = 'Checking radio...'; $topRadioButton.IsEnabled = $false
    [void]$script:topPanelItems.Children.Add($topRadioButton)
    $script:topRadioMessage = Add-TopText ''
    try { $script:topRadioLoad = ConvertTo-MediaTask ([Windows.Devices.Radios.Radio]::GetRadiosAsync()) ([Collections.Generic.IReadOnlyList[Windows.Devices.Radios.Radio]]) } catch { $topRadioMessage.Text = 'Use Settings to manage this radio.' }
    $topRadioButton.Add_Click({
        $script:topRadioButton.IsEnabled = $false
        try { $script:topRadioAccess = ConvertTo-MediaTask ([Windows.Devices.Radios.Radio]::RequestAccessAsync()) ([Windows.Devices.Radios.RadioAccessStatus]) } catch { $script:topRadioMessage.Text = 'Permission unavailable. Use Settings.' }
    })
}
function Add-TopNetworks {
    try {
        $networks = @([MenuWifi]::Networks() | Sort-Object -Property @{Expression='Connected';Descending=$true},@{Expression='Signal';Descending=$true} | Group-Object Name | ForEach-Object { $_.Group[0] })
        if (-not $networks.Count) { [void](Add-TopText 'No nearby networks. Check that Wi-Fi is on.'); return }
        foreach ($network in $networks) {
            $row = [Windows.Controls.Button]::new(); $row.Style = $script:topPanelButtonStyle; $row.Tag = $network
            $name = [Windows.Controls.TextBlock]::new(); $name.Text = $(if($network.Connected){[char]0x2713 + '  '}else{''}) + $network.Name; $name.TextTrimming = 'CharacterEllipsis'; $name.MaxWidth = 250
            $row.Content = $name; $row.ToolTip = $network.Name + ' | Signal ' + $network.Signal + '%' + $(if($network.Secure){' | Secured'}else{' | Open'})
            if ($network.Connected) { $row.Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#553478F6') }
            $row.Add_Click({
                param($sender,$e)
                if ($sender.Tag.Connected) { return }
                if (-not $sender.Tag.Profile) { Invoke-TopAction 'ms-settings:network-wifi'; return }
                try { [MenuWifi]::Connect($sender.Tag); $script:topRadioMessage.Text = 'Connection requested. Refresh to check status.' } catch { $script:topRadioMessage.Text = 'Could not connect. Open Wi-Fi Settings.' }
            })
            [void]$script:topPanelItems.Children.Add($row)
        }
    } catch { [void](Add-TopText 'Windows could not provide nearby networks. Check Wi-Fi and location permission in Settings.') }
}
function Show-TopPanel([string]$Kind,$Anchor) {
    if ($Kind -eq 'Search') { Show-AppSearch; return }
    $script:topPanel.IsOpen = $false
    Set-TopGlassMaterial $false
    $script:topPanelItems.Children.Clear(); $script:topPanelKind = $Kind
    $script:topRadioLoad = $null; $script:topRadioAccess = $null; $script:topRadioSet = $null; $script:topRadio = $null; $script:topVolume = $null; $script:topMute = $null
    $script:topPanel.PlacementTarget = $Anchor
    switch ($Kind) {
        'Wi-Fi' {
            [void](Add-TopText 'Wi-Fi' 17 'White'); Add-TopRadio 'WiFi'; Add-TopDivider
            [void](Add-TopText 'Nearby networks' 11); Add-TopNetworks
            Add-TopDivider; [void](Add-TopAction 'Refresh networks' 'panel:Wi-Fi'); [void](Add-TopAction 'Wi-Fi Settings...' 'ms-settings:network-wifi')
        }
        'Sound' {
            [void](Add-TopText 'Sound' 17 'White'); Add-TopVolume; Add-TopDivider
            [void](Add-TopText 'Output' 11); [void](Add-TopText 'System default audio device' 13 'White')
            [void](Add-TopAction 'Output devices & Sound Settings...' 'ms-settings:sound')
        }
        'Bluetooth' {
            [void](Add-TopText 'Bluetooth' 17 'White'); Add-TopRadio 'Bluetooth'; Add-TopDivider
            [void](Add-TopAction 'Devices & pairing...' 'ms-settings:bluetooth')
        }
        'Battery' {
            [void](Add-TopText 'Battery' 17 'White')
            $power = [Windows.Forms.SystemInformation]::PowerStatus
            [void](Add-TopText ([string]$script:topBarWindow.FindName('TopBattery').Content) 32 'White')
            [void](Add-TopText $(if($power.PowerLineStatus -eq 'Online'){'Power source: Power adapter'}else{'Power source: Battery'}))
            if ($power.BatteryLifeRemaining -gt 0) { [void](Add-TopText ('Estimated time remaining: {0:0} minutes' -f ($power.BatteryLifeRemaining/60))) }
            Add-TopDivider; [void](Add-TopAction 'Battery Settings...' 'ms-settings:batterysaver')
        }
        'Calendar' {
            [void](Add-TopText ([DateTime]::Now.ToString('dddd, MMMM d')) 17 'White')
            $calendar = [Windows.Controls.Calendar]::new(); $calendar.DisplayDate = [DateTime]::Today; $calendar.SelectedDate = [DateTime]::Today
            [void]$script:topPanelItems.Children.Add($calendar)
            [void](Add-TopAction 'Date & Time Settings...' 'ms-settings:dateandtime')
        }
        'Search' {
            [void](Add-TopText 'Search' 17 'White'); [void](Add-TopAction 'Search apps, files and the web...' 'search-ms:')
        }
        default {
            [void](Add-TopText 'Control Center' 17 'White')
            $tiles=[Windows.Controls.WrapPanel]::new()
            Add-TopTile $tiles ([string][char]0xE701) 'Wi-Fi' 'panel:Wi-Fi'
            Add-TopTile $tiles ([string][char]0xE702) 'Bluetooth' 'panel:Bluetooth'
            Add-TopTile $tiles ([string][char]0xE708) 'Focus' 'ms-settings:quiethours'
            Add-TopTile $tiles ([string][char]0xE7F4) 'Display' 'ms-settings:display'
            [void]$script:topPanelItems.Children.Add($tiles)
            [void](Add-TopAction 'Screen projection...' 'ms-settings:project')
            Add-TopVolume; Add-TopDivider
            [void](Add-TopAction 'Sound Settings...' 'ms-settings:sound')
            [void](Add-TopAction 'Customize menu bar...' 'customize')
        }
    }
    $script:topPanel.IsOpen = $true
}
function Update-TopPanelState {
    if (-not $script:topPanel.IsOpen) { return }
    if (-not $script:topBarEntry.Enabled) { $script:topPanel.IsOpen = $false; return }
    if ($script:topRadioLoad -and $script:topRadioLoad.IsCompleted) {
        try {
            if ($script:topRadioLoad.IsFaulted) { throw 'Radio query failed' }
            $script:topRadio = @($script:topRadioLoad.Result | Where-Object { $_.Kind.ToString() -eq $script:topRadioKind }) | Select-Object -First 1
            $script:topRadioButton.IsEnabled = $null -ne $script:topRadio
            $script:topRadioMessage.Text = if ($script:topRadio) { '' } else { 'No controllable adapter. Open Settings.' }
            if (-not $script:topRadio) { $script:topRadioButton.Content = 'Unavailable' }
        } catch { $script:topRadioMessage.Text = 'Radio status unavailable. Open Settings.' }
        $script:topRadioLoad = $null
    }
    if ($script:topRadioAccess -and $script:topRadioAccess.IsCompleted) {
        try {
            if ($script:topRadioAccess.IsFaulted -or $script:topRadioAccess.Result.ToString() -ne 'Allowed') { throw 'Not allowed' }
            $state = if ($script:topRadio.State.ToString() -eq 'On') { [Windows.Devices.Radios.RadioState]::Off } else { [Windows.Devices.Radios.RadioState]::On }
            $script:topRadioSet = ConvertTo-MediaTask ($script:topRadio.SetStateAsync($state)) ([Windows.Devices.Radios.RadioAccessStatus])
        } catch { $script:topRadioMessage.Text = 'Windows did not allow this change. Use Settings.'; $script:topRadioButton.IsEnabled = $true }
        $script:topRadioAccess = $null
    }
    if ($script:topRadioSet -and $script:topRadioSet.IsCompleted) {
        $script:topRadioMessage.Text = if ($script:topRadioSet.IsFaulted -or $script:topRadioSet.Result.ToString() -ne 'Allowed') { 'Windows did not allow this change.' } else { 'Updated' }
        $script:topRadioSet = $null; $script:topRadioButton.IsEnabled = $true
    }
    if ($script:topRadioMessage) { $script:topRadioMessage.Visibility = if ($script:topRadioMessage.Text) { 'Visible' } else { 'Collapsed' } }
    if ($script:topRadio) { Set-TopRadioVisual }
    if ($script:topVolume -and -not $script:topVolume.IsMouseCaptureWithin -and -not $script:topVolume.IsKeyboardFocusWithin) {
        $script:topPanelUpdating = $true
        try { $script:topVolume.Value = [MenuAudio]::Volume()*100; $script:topVolumeLabel.Text = 'Sound   ' + [Math]::Round($script:topVolume.Value) + '%'; $script:topMute.Content = if ([MenuAudio]::Muted()) { 'Unmute' } else { 'Mute' } } catch { $script:topVolumeLabel.Text = 'Audio output unavailable' } finally { $script:topPanelUpdating = $false }
    }
}
foreach ($pair in @(@('NetworkStatus','Wi-Fi'),@('SoundSettings','Sound'),@('BluetoothStatus','Bluetooth'),@('TopBattery','Battery'),@('TopClock','Calendar'),@('BarSettings','Control Center'),@('SearchMenu','Search'))) {
    $button = $topBarWindow.FindName($pair[0]); $button.Tag = $pair[1]
    $button.Add_Click({ param($sender,$e) Show-TopPanel ([string]$sender.Tag) $sender })
}
# Use the same material and rounded surfaces for the left-side menus.
[xml]$topMenuStyleXaml = @"
<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" TargetType="ContextMenu">
 <Setter Property="Background" Value="#FF303A49"/><Setter Property="Foreground" Value="White"/>
 <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ContextMenu"><Border Background="{TemplateBinding Background}" BorderBrush="#70D5E2F5" BorderThickness="1" CornerRadius="14" Padding="6"><StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Cycle"/></Border></ControlTemplate></Setter.Value></Setter>
</Style>
"@
$script:topMenuGlassStyle = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($topMenuStyleXaml))
foreach($name in @('DesktopMenu','FinderMenu','FileMenu','ViewMenu','GoMenu','WidgetsMenu','HelpMenu')) {
    $menu=$topBarWindow.FindName($name).ContextMenu; $menu.Style=$script:topMenuGlassStyle
    $menu.Add_Opened({
        param($sender,$e)
        $source=[Windows.PresentationSource]::FromVisual($sender)
        $blurred=$false
        if(-not $Preview -and -not [Windows.SystemParameters]::HighContrast -and $source -is [Windows.Interop.HwndSource]) { $blurred=[MenuGlass]::Apply($source.Handle,[int](14*$source.CompositionTarget.TransformToDevice.M11)) }
        $sender.Background=[Windows.Media.BrushConverter]::new().ConvertFromString($(if($blurred){'#B8303A49'}else{'#FF303A49'}))
    })
}
