$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ClockWidget.ps1') -Preview
try {
    $work = [Windows.Rect]::new(0,0,1280,720)
    $position = Get-WidgetPlacement $script:macDockEntry $work
    if ($position.X -ne (($work.Width - $macDockWindow.Width) / 2) -or $position.Y + $macDockWindow.Height -gt $work.Bottom) { throw 'Dock must be centered within the work area.' }
    $position = Get-WidgetPlacement $script:topBarEntry $work
    if ($position.X -ne 0 -or $position.Y -ne 0 -or $topBarWindow.Width -ne 1280) { throw 'Menu bar must span the work area.' }
    if ($script:widgetPreferences.widgets.TopBar.pinned -or -not $script:widgetPreferences.widgets.MacDock.pinned) { throw 'Taskbar should be pinned and top bar should auto-hide.' }
    $migrated = ConvertTo-WidgetPreferences ('{"widgets":{"Dock":{"enabled":false,"pinned":false}}}' | ConvertFrom-Json)
    if ($migrated.widgets.Dock.enabled -or -not $migrated.widgets.TopBar.enabled) { throw 'Migration lost the dock setting or the new bar.' }
    $script:widgetPreferences.timeFormat = '12-hour'
    Update-TopMenuBar
    if ($topBarWindow.FindName('TopClock').Content -notmatch '(AM|PM)$') { throw 'Top bar ignored time format.' }
    $go = $topBarWindow.FindName('GoMenu')
    $go.ContextMenu.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.ContextMenu]::OpenedEvent))
    if (-not $script:topBarEntry.Configuring) { throw 'Open menus must keep the bar visible.' }
    $go.ContextMenu.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.ContextMenu]::ClosedEvent))
    if ($script:topBarEntry.Configuring) { throw 'Closed menu retained the visibility lock.' }
    foreach ($width in @(800,1280,1920)) {
        $point = Get-WidgetPlacement $script:topBarEntry ([Windows.Rect]::new(0,0,$width,720))
        if ($topBarWindow.Width -ne $width) { throw 'Menu bar did not adapt to screen width.' }
    }
    [void](Get-WidgetPlacement $script:topBarEntry $work)
    $form = New-WidgetSettingsWindow
    if (-not $script:settingsRows.ContainsKey('Dock') -or -not $script:settingsRows.ContainsKey('TopBar') -or $script:settingsRows.TopBar.x.IsEnabled) { throw 'Bar settings are incomplete.' }
    $dwell = @{}
    $now = [DateTime]::Now
    if (Test-TopBarDwell $dwell $true $now) { throw 'Top bar appeared immediately' }
    if (Test-TopBarDwell $dwell $true $now.AddMilliseconds(999)) { throw 'Top bar appeared before one second' }
    if (-not (Test-TopBarDwell $dwell $true $now.AddMilliseconds(1000))) { throw 'Top bar did not appear after one second' }
    [void](Test-TopBarDwell $dwell $false $now.AddMilliseconds(1100))
    if (Test-TopBarDwell $dwell $true $now.AddMilliseconds(1500)) { throw 'Leaving the edge must reset dwell' }
    Update-MacDockTasks
    if ($macDockWindow.FindName('MacDockButtons').Children.Count -ne ($script:macDockPaths.Count + 3)) { throw 'Dock should contain Start, pinned apps, running apps and tray.' }
    $script:widgetPreferences.dockWidth = 96
    $wide = Get-WidgetPlacement $script:macDockEntry $work
    if ([Math]::Abs($macDockWindow.Width - 1228.8) -gt 0.1) { throw 'Dock width should use 96 percent of the work area.' }
    $script:widgetPreferences.dockWidth = 70
    [void](Get-WidgetPlacement $script:macDockEntry $work)
    if ($macDockWindow.Width -ne 896) { throw 'Dock width preference was ignored.' }
    $script:widgetPreferences.dockWidth = 96
    [void](Get-WidgetPlacement $script:macDockEntry $work)
    foreach ($entry in @($script:dockEntry,$script:macDockEntry,$script:topBarEntry)) {
        $entry.Window.Opacity = 1; $entry.Slide.X = 0; $entry.Slide.Y = 0
        $entry.Window.Show(); $entry.Window.UpdateLayout()
        $bitmap = [Windows.Media.Imaging.RenderTargetBitmap]::new([int]($entry.Window.Width * 2),[int]($entry.Window.Height * 2),192,192,[Windows.Media.PixelFormats]::Pbgra32)
        $bitmap.Render($entry.Window)
        $encoder = [Windows.Media.Imaging.PngBitmapEncoder]::new()
        $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
        $stream = [IO.File]::Create((Join-Path $PSScriptRoot ('preview-' + $entry.Name + '.png')))
        try { $encoder.Save($stream) } finally { $stream.Dispose() }
    }
    $context = $macDockWindow.ContextMenu
    $context.PlacementTarget = $macDockWindow; $context.IsOpen = $true; $context.UpdateLayout()
    if ($context.ActualWidth -lt 235 -or $context.ActualHeight -lt 50) { throw 'Context menu did not render.' }
    $bitmap = [Windows.Media.Imaging.RenderTargetBitmap]::new([int]($context.ActualWidth*2),[int]($context.ActualHeight*2),192,192,[Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($context)
    $encoder = [Windows.Media.Imaging.PngBitmapEncoder]::new(); $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream = [IO.File]::Create((Join-Path $PSScriptRoot 'preview-context-menu.png'))
    try { $encoder.Save($stream) } finally { $stream.Dispose(); $context.IsOpen = $false }
    Write-Output 'Desktop bars: app-only content, width preference, placement, defaults, migration, menus, clock, settings and WPF rendering passed.'
} finally {
    if ($script:settingsWindow) { $script:settingsWindow.Close() }
    foreach ($entry in $script:cornerCards) { $entry.Window.Close() }
}
