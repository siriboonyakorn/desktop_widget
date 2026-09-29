param([switch]$VerifySeek)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ClockWidget.ps1') -Preview
$Preview = $false
Start-Media
for ($i = 0; $i -lt 8; $i++) { Start-Sleep -Milliseconds 250; Update-Media }
if (-not $script:mediaSession) { throw 'No active media session to verify' }
[pscustomobject]@{ Title = $mediaTitle.Text; SeekEnabled = $mediaSeek.IsEnabled; Elapsed = $mediaElapsed.Text; Duration = $mediaDuration.Text; PlayButton = $mediaPlay.Content }
if ($VerifySeek) {
    $session = $script:mediaSession
    if ($session.GetPlaybackInfo().PlaybackStatus.ToString() -ne 'Paused') { throw 'Seek test requires paused media to preserve playback state' }
    $original = $session.GetTimelineProperties().Position.TotalSeconds
    try {
        $mediaForward.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
        for ($i = 0; $i -lt 8; $i++) { Start-Sleep -Milliseconds 250; Update-Media }
        $actual = $session.GetTimelineProperties().Position.TotalSeconds
        if ([Math]::Abs($actual - ($original + 10)) -gt 1) { throw "Forward control failed: $original -> $actual" }
        $mediaBack.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
        for ($i = 0; $i -lt 8; $i++) { Start-Sleep -Milliseconds 250; Update-Media }
        $actual = $session.GetTimelineProperties().Position.TotalSeconds
        if ([Math]::Abs($actual - $original) -gt 1) { throw "Back control failed: $actual" }
        $script:draggingSeek = $true
        $script:dragSession = $session
        $mediaSeek.Value = $original + 5
        Complete-MediaDrag
        for ($i = 0; $i -lt 8; $i++) { Start-Sleep -Milliseconds 250; Update-Media }
        $actual = $session.GetTimelineProperties().Position.TotalSeconds
        if ([Math]::Abs($actual - ($original + 5)) -gt 1) { throw "Timeline seek failed: $actual" }
        Write-Output 'Live +10 / -10 buttons and timeline seek tests passed.'
    } finally {
        $restore = ConvertTo-MediaTask ($session.TryChangePlaybackPositionAsync([TimeSpan]::FromSeconds($original).Ticks)) ([bool])
        if (-not $restore.Wait(5000) -or -not $restore.Result) { throw 'Could not restore the original video position' }
    }
}
