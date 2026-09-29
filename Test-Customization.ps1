$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ClockWidget.ps1') -Preview
$originalPath = $script:customizationPath
$script:customizationPath = Join-Path $PSScriptRoot ('test-customization-' + [Guid]::NewGuid().ToString('N') + '.json')
try {
    $clean = ConvertTo-WidgetPreferences ('{"theme":"invalid","glassOpacity":4,"clockScale":-2,"motion":"false","widgets":{"Photo":{"scale":99,"enabled":false,"x":"NaN"}}}' | ConvertFrom-Json)
    if ($clean.theme -ne 'Glass' -or $clean.glassOpacity -ne 1 -or $clean.clockScale -ne 0.65 -or -not $clean.motion -or $clean.widgets.Photo.scale -ne 1.5 -or $clean.widgets.Photo.enabled -or $clean.widgets.Photo.x -ne 0) { throw 'Preference validation failed' }
    Save-WidgetPreferences $clean
    $roundTrip = ConvertTo-WidgetPreferences (Get-Content -LiteralPath $script:customizationPath -Raw | ConvertFrom-Json)
    if ($roundTrip.widgets.Photo.enabled -or $roundTrip.widgets.Photo.scale -ne 1.5) { throw 'Nested preferences did not persist' }
    $script:widgetPreferences.weatherUnits = 'Fahrenheit'
    Set-WeatherData ([pscustomobject]@{ current = [pscustomobject]@{ temperature_2m = 0; apparent_temperature = 10; relative_humidity_2m = 50; wind_speed_10m = 16.09344; weather_code = 0; time = '2026-09-27T12:00'; is_day = 1 } })
    if ($weatherTemperature.Text -ne ('32' + [char]0x00B0) -or $weatherWind.Text -ne '10 mph wind' -or $weatherFeels.Text -ne ('Feels like 50' + [char]0x00B0 + 'F')) { throw 'Weather conversion failed' }
    $script:widgetPreferences.weatherUnits = 'Celsius'
    $form = New-WidgetSettingsWindow
    $form.Show(); $form.UpdateLayout()
    if ($script:settingsRows.Count -ne 12) { throw 'Settings must include all twelve cards' }
    $form.FindName('DockWidth').Value = 78
    $form.FindName('Theme').SelectedItem = 'Midnight'
    $form.FindName('Accent').SelectedItem = 'Mint'
    $form.FindName('TimeFormat').SelectedItem = '12-hour'
    $form.FindName('Seconds').IsChecked = $true
    $form.FindName('Media').IsChecked = $false
    $form.FindName('Motion').IsChecked = $false
    $form.FindName('ClockStyle').SelectedItem = 'Minimal'
    $form.FindName('PhotoFit').SelectedItem = 'Fit'
    $script:settingsRows.Photo.scale.Value = 125
    $script:settingsRows.Weather.scale.Value = 125
    $script:settingsRows.Battery.enabled.IsChecked = $false
    $script:settingsRows.Photo.pinned.IsChecked = $true
    $script:settingsRows.Dock.x.Text = '23'
    Save-SettingsForm
    if ($form.FindName('SettingsStatus').Text -ne 'Saved. Your desktop is ready.') { throw $form.FindName('SettingsStatus').Text }
    if ($script:widgetPreferences.dockWidth -ne 78 -or (Get-Content -LiteralPath $script:customizationPath -Raw | ConvertFrom-Json).dockWidth -ne 78) { throw 'Dock width did not persist' }
    if ((Get-WidgetTimeFormat) -ne 'h:mm:ss tt' -or $mediaPanel.Visibility -ne 'Collapsed' -or $script:photoEntry.Window.Width -ne 267.5 -or -not $script:photoEntry.Pinned) { throw 'Settings did not apply to widgets' }
    if ($script:selectedStyle -ne 'Minimal' -or (Get-Content -LiteralPath $script:customizationPath -Raw | ConvertFrom-Json).clockStyle -ne 'Minimal') { throw 'Clock style did not persist with preferences' }
    $weather = $script:cornerCards | Where-Object Name -eq 'Weather'
    $work = [Windows.Rect]::new(0,0,1920,1040)
    $wp = Get-WidgetPlacement $weather $work; $pp = Get-WidgetPlacement $script:photoEntry $work
    if ($wp.X - $pp.X - $photoWindow.Width -ne 14) { throw 'Resizing lost the photo/weather gap' }
    $script:widgetPreferences.widgets.Photo.x = 9999; $script:widgetPreferences.widgets.Photo.y = -9999
    $clamped = Get-WidgetPlacement $script:photoEntry ([Windows.Rect]::new(0,0,1280,680))
    if ($clamped.X + $photoWindow.Width -gt 1280 -or $clamped.Y -lt 0) { throw 'Widget escaped the work area' }
    $savedBefore = Get-Content -LiteralPath $script:customizationPath -Raw
    $script:settingsRows.Photo.x.Text = 'bad'
    Save-SettingsForm
    if ((Get-Content -LiteralPath $script:customizationPath -Raw) -ne $savedBefore -or $form.FindName('SettingsStatus').Text -notmatch 'Enter a number') { throw 'Invalid input overwrote preferences' }
    $form.FindName('ResetLayout').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    Save-SettingsForm
    if ($script:widgetPreferences.widgets.Photo.scale -ne 1 -or $script:widgetPreferences.widgets.Photo.x -ne 0 -or $script:widgetPreferences.widgets.Photo.y -ne 0) { throw 'Reset layout failed' }
    $script:widgetDrag = @{ Window = $photoWindow; Name = 'Photo'; Left = 100; Top = 100 }
    $photoWindow.Left = 125; $photoWindow.Top = 115; $script:photoEntry.Dragging = $true
    Complete-WidgetDrag
    if ($script:photoEntry.Dragging -or $script:widgetDrag -or $script:widgetPreferences.widgets.Photo.x -ne 25 -or $script:widgetPreferences.widgets.Photo.y -ne 15) { throw 'Drag completion failed' }
    # Restore defaults for visual review, without reading any personal photo or note.
    $script:widgetPreferences = New-WidgetPreferences
    Apply-WidgetPreferences; Set-SettingsForm
    $form.FindName('SettingsStatus').Text = 'Changes take effect when you click Apply.'
    foreach ($index in @(0,1,2)) {
        $form.FindName('SettingsTabs').SelectedIndex = $index; $form.UpdateLayout()
        $bitmap = [Windows.Media.Imaging.RenderTargetBitmap]::new([int]$form.ActualWidth,[int]$form.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32)
        $bitmap.Render($form)
        $encoder = [Windows.Media.Imaging.PngBitmapEncoder]::new(); $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
        $stream = [IO.File]::Create((Join-Path $PSScriptRoot "preview-settings-$index.png"))
        try { $encoder.Save($stream) } finally { $stream.Dispose() }
    }
    Write-Output 'Settings UI, validation, persistence, scaling, framing options, clock formatting, offsets, screen bounds, and reset checks passed.'
} finally {
    if ($script:settingsWindow) { $script:settingsWindow.Close() }
    foreach ($entry in $script:cornerCards) { $entry.Window.Close() }
    if (Test-Path -LiteralPath $script:customizationPath) { Remove-Item -LiteralPath $script:customizationPath }
    $script:customizationPath = $originalPath
}
