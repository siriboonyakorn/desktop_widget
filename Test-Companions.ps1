$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'ClockWidget.ps1') -Preview
$script:companionStatePath = Join-Path $PSScriptRoot ('test-companion-' + [Guid]::NewGuid().ToString('N') + '.json')
try {
    $today=[DateTime]'2026-09-27T12:00:00'
    $companionState.day=$today.ToString('yyyy-MM-dd'); $companionState.seconds=0.0
    Add-CompanionActivity $today 5 0 $true
    Add-CompanionActivity $today 5 80 $true
    Add-CompanionActivity $today 5 0 $false
    Add-CompanionActivity $today 3600 0 $true
    if ($companionState.seconds -ne 5) { throw 'Idle, lock, or sleep was counted as activity' }
    Add-CompanionActivity ($today.Date.AddDays(1).AddSeconds(2)) 5 0 $true
    if ($companionState.seconds -ne 2) { throw 'Midnight rollover failed' }
    Add-CompanionActivity ($today.Date.AddDays(2).AddSeconds(2)) 3600 0 $true
    if ($companionState.seconds -ne 0) { throw 'Sleep across midnight was counted' }
    $utc=[DateTime]::UtcNow
    $companionState.nextAt=$utc.AddHours(1).ToString('o')
    if (Test-PetReminderDue $companionState $utc $true $true 0 $true) { throw 'Reminder fired too early' }
    $companionState.nextAt=$utc.AddSeconds(-1).ToString('o')
    if (-not (Test-PetReminderDue $companionState $utc $true $true 0 $true)) { throw 'Due reminder missed' }
    foreach ($gates in @(@($false,$true,0,$true),@($true,$false,0,$true),@($true,$true,90,$true),@($true,$true,0,$false))) {
        if (Test-PetReminderDue $companionState $utc $gates[0] $gates[1] $gates[2] $gates[3]) { throw 'Notification suppression failed' }
    }
    $companionState.muted=$true
    if (Test-PetReminderDue $companionState $utc $true $true 0 $true) { throw 'Mute ignored' }
    $companionState.muted=$false
    Set-PetSnooze
    if (Test-PetReminderDue $companionState $utc $true $true 0 $true) { throw 'Snooze ignored' }
    $companionState.snoozeUntil=''
    $Preview=$false; Save-CompanionState; $Preview=$true
    $saved=Get-Content -LiteralPath $companionStatePath -Raw | ConvertFrom-Json
    if ($saved.seconds -ne $companionState.seconds -or $script:companionSaveFailed) { throw 'Screen time persistence failed' }
    $data=[pscustomobject]@{ daily=[pscustomobject]@{ time=@('2026-09-27','2026-09-28'); sunrise=@('2026-09-27T06:08','2026-09-28T06:09'); sunset=@('2026-09-27T18:12','2026-09-28T18:11') } }
    if ((Get-DaylightState $today $data).Estimated -or -not (Get-DaylightState $today $data).Day) { throw 'Daylight data failed' }
    $progress=(Get-DaylightState $today $data).Progress
    if ($progress -lt 0.45 -or $progress -gt 0.55) { throw 'Noon sun must be near the middle of its arc' }
    if ((Get-DaylightState ($today.Date.AddHours(18.2)) $data).Day) { throw 'Sunset boundary failed' }
    if ((Get-DaylightState ($today.Date.AddHours(22)) $data).Detail -notlike 'Sunrise 06:09*') { throw 'Tomorrow sunrise failed' }
    if (-not (Get-DaylightState ($today.AddDays(4)) $data).Estimated) { throw 'Stale sunrise data accepted' }
    if (-not (Get-DaylightState $today $null).Estimated) { throw 'Offline estimate must be labeled' }
    foreach ($name in @('Pet','Daylight')) {
        if (-not $widgetPreferences.widgets[$name].pinned) { throw 'New companion should stay visible on desktop' }
        $entry=$cornerCards | Where-Object Name -eq $name
        $point=Get-WidgetPlacement $entry ([Windows.Rect]::new(0,0,800,600))
        if ($point.X -lt 0 -or $point.Y -lt 0 -or $point.X+$entry.Window.Width -gt 800 -or $point.Y+$entry.Window.Height -gt 600) { throw 'Companion outside work area' }
    }
    $petWindow.Opacity=1; $daylightWindow.Opacity=1
    $petWindow.Show(); $daylightWindow.Show()
    $companionState.seconds=4980
    $petWindow.FindName('PetToday').Text='Active today: 1h 23m'
    Show-PetNudge
    if (-not $petToast.IsVisible -or $petToast.FindName('ToastMessage').Text -notlike '*1h 23m*') { throw 'Nudge failed to show screen time' }
    $previous=$petLastTip; Show-PetNudge
    if ($previous -eq $petLastTip) { throw 'Consecutive tip repeated' }
    $petToast.FindName('SnoozePet').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    if ($petToast.IsVisible -or -not $companionState.snoozeUntil) { throw 'Snooze button failed' }
    Show-PetNudge
    $petToast.FindName('ToastMessage').Text="It's 17:30. About 1h 23m active today.`nLet your shoulders drop and relax your hands."
    $petWindow.FindName('PetCaption').Text='Tiny buddy. Gentle reminders.'
    $visual=[Windows.Media.DrawingVisual]::new(); $draw=$visual.RenderOpen()
    $draw.DrawRectangle([Windows.Media.BrushConverter]::new().ConvertFromString('#101B29'),$null,[Windows.Rect]::new(0,0,920,480))
    $x=12
    foreach ($hour in @(6.5,12,17.5)) {
        Update-Daylight ($today.Date.AddHours($hour)) $data
        $daylightWindow.UpdateLayout()
        $daylightWindow.Dispatcher.Invoke([Action]{},[Windows.Threading.DispatcherPriority]::Render)
        # Capture each phase before changing the shared visual.
        $frame=[Windows.Media.Imaging.RenderTargetBitmap]::new(512,432,192,192,[Windows.Media.PixelFormats]::Pbgra32)
        $frame.Render($daylightWindow)
        $draw.DrawImage($frame,[Windows.Rect]::new($x,10,256,216)); $x+=270
    }
    Update-Daylight ($today.Date.AddHours(22)) $data
    $daylightWindow.UpdateLayout(); $petWindow.UpdateLayout(); $petToast.UpdateLayout()
    $daylightWindow.Dispatcher.Invoke([Action]{},[Windows.Threading.DispatcherPriority]::Render)
    $draw.DrawRectangle([Windows.Media.VisualBrush]::new($daylightWindow),$null,[Windows.Rect]::new(12,240,256,216))
    $draw.DrawRectangle([Windows.Media.VisualBrush]::new($petWindow),$null,[Windows.Rect]::new(280,230,240,244))
    $draw.DrawRectangle([Windows.Media.VisualBrush]::new($petToast),$null,[Windows.Rect]::new(532,260,370,190))
    $draw.Close()
    $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(1840,960,192,192,[Windows.Media.PixelFormats]::Pbgra32); $bitmap.Render($visual)
    $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new(); $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream=[IO.File]::Create((Join-Path $PSScriptRoot 'preview-companions.png'))
    try { $encoder.Save($stream) } finally { $stream.Dispose() }
    $petToast.FindName('DismissPet').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    if ($petToast.IsVisible) { throw 'Dismiss button failed' }
    Write-Output 'PASS: idle/lock/sleep exclusion, midnight reset, reminder gates, mute, snooze, persistence, daylight boundaries/offline data, positioning, and reminder controls.'
    Write-Output "Native activity API: idle=$([CompanionNative]::IdleSeconds())s; unlocked=$([CompanionNative]::Unlocked()); canNotify=$([CompanionNative]::CanNotify())"
} finally {
    $Preview=$true
    $petToast.Close()
    foreach ($entry in $cornerCards) { $entry.Window.Close() }
    foreach ($path in @($companionStatePath,($companionStatePath+'.tmp'))) { if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path } }
}
