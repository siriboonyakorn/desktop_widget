$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ClockWidget.ps1') -Preview
$feb = @(Get-CalendarCells ([DateTime]'2024-02-01') ([DateTime]'2024-02-29'))
if (@($feb | Where-Object { $_.Label }).Count -ne 29) { throw 'Leap month failed' }
if ($feb[3].Label -ne '1' -or @($feb | Where-Object Today).Count -ne 1) { throw 'Monday-first or today highlight failed' }
$sixRows = @(Get-CalendarCells ([DateTime]'2026-03-01') ([DateTime]'2026-03-31'))
if ($sixRows[36].Label -ne '31') { throw 'Six-row month failed' }
if (-not (Test-CornerProximity 0 0) -or -not (Test-CornerProximity 220 220) -or (Test-CornerProximity 300 220)) { throw 'Hover boundary failed' }
Start-CornerWidgets
try {
    $calendar = $script:cornerCards[0]
    $battery = $script:cornerCards[1]
    $weather = $script:cornerCards | Where-Object Name -eq 'Weather'
    $expectedRight = [Windows.SystemParameters]::WorkArea.Right - $weather.Window.Width - 10
    if ([Math]::Abs($weather.Window.Left - $expectedRight) -gt 1) { throw 'Weather top-right placement failed' }
    Set-CornerVisible $true $calendar
    if (-not $calendar.Visible -or ([DesktopHost]::GetWindowLong($calendar.Handle, -20) -band 0x20)) { throw 'Visible calendar should accept clicks' }
    if ($battery.Visible -or -not ([DesktopHost]::GetWindowLong($battery.Handle, -20) -band 0x20)) { throw 'Calendar reveal must not reveal the battery' }
    Set-CornerVisible $false $calendar
    Set-CornerVisible $true $battery
    if ($calendar.Visible -or -not ([DesktopHost]::GetWindowLong($calendar.Handle, -20) -band 0x20)) { throw 'Hidden calendar should pass clicks through' }
    if (-not $battery.Visible -or $battery.Slide.X -ne 0) { throw 'Battery reveal or vertical direction failed' }
    Set-CornerVisible $false $battery
    Set-CornerVisible $true $weather
    if (-not $weather.Visible -or $calendar.Visible -or $battery.Visible) { throw 'Weather reveal must be independent' }
    Set-CornerVisible $false $weather
    if (-not ([DesktopHost]::GetWindowLong($weather.Handle, -20) -band 0x20)) { throw 'Hidden weather card should pass clicks through' }
    $dock = $script:cornerCards | Where-Object Name -eq 'Dock'
    $work = [Windows.SystemParameters]::WorkArea
    if ($dock.Window.Left -ne ($work.Left + 4) -or [Math]::Abs($dock.Window.Top - ($work.Top + ($work.Height - 276) / 2)) -gt 1) { throw 'Dock left-center placement failed' }
    if ($script:dockButtons.Count -ne 5 -or $dock.Window.Width -ne 70) { throw 'Compact five-slot dock failed' }
    foreach ($button in $script:dockButtons) {
        if ((Test-Path -LiteralPath $script:dockPaths[[int]$button.Tag] -PathType Leaf) -and $button.Content -isnot [Windows.Controls.Image]) { throw 'Shortcut icon failed' }
    }
    Set-CornerVisible $true $dock
    if (-not $dock.Visible -or ([DesktopHost]::GetWindowLong($dock.Handle, -20) -band 0x20) -or $dock.Slide.Y -ne 0) { throw 'Dock reveal or horizontal animation failed' }
    if ($calendar.Visible -or $battery.Visible -or $weather.Visible) { throw 'Dock should reveal independently' }
    Set-CornerVisible $false $dock
    if (-not ([DesktopHost]::GetWindowLong($dock.Handle, -20) -band 0x20)) { throw 'Hidden dock should pass clicks through' }
    $note = $script:cornerCards | Where-Object Name -eq 'QuickNote'
    if ($note.Window.Left -ne $weather.Window.Left -or $note.Window.Top -ne ($weather.Window.Top + 248)) { throw 'Quick note must sit below weather' }
    if ([DesktopHost]::GetWindowLong($note.Handle, -20) -band 0x08000000) { throw 'Quick note must allow keyboard activation' }
    Set-CornerVisible $true $note
    if (-not $note.Visible -or $weather.Visible -or ([DesktopHost]::GetWindowLong($note.Handle, -20) -band 0x20)) { throw 'Quick note must reveal independently and accept clicks' }
    Set-CornerVisible $false $note
    if (-not ([DesktopHost]::GetWindowLong($note.Handle, -20) -band 0x20)) { throw 'Hidden quick note should pass clicks through' }
    Update-CornerHover
    Write-Output 'Calendar, independent reveals, vertical animation, hover boundaries, and hidden click-through checks passed.'
    Write-Output "Battery: $($batteryPercent.Text), $($batteryState.Text)"
    Write-Output 'Dock: five shortcut icons, left-center placement, independent reveal and hidden click-through passed.'
    Write-Output 'Quick note: below-weather placement, keyboard activation, independent reveal and hidden click-through passed.'
} finally {
    $script:cornerTimer.Stop()
    foreach ($entry in $script:cornerCards) { $entry.Window.Close() }
}
