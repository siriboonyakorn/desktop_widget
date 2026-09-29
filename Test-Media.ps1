param([switch]$Probe)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'MediaSession.ps1')
if ((Format-MediaTime 3661) -ne '1:01:01') { throw 'Hour formatting failed' }
if ((Format-MediaTime 65) -ne '1:05') { throw 'Minute formatting failed' }
if ((Limit-MediaSeek -10 0 90) -ne 0 -or (Limit-MediaSeek 110 0 90) -ne 90) { throw 'Seek limits failed' }
$now = [DateTimeOffset]::Now
$timeline = [pscustomobject]@{ Position = [TimeSpan]::FromSeconds(20); StartTime = [TimeSpan]::Zero; EndTime = [TimeSpan]::FromSeconds(60); LastUpdatedTime = $now.AddSeconds(-4) }
$playback = [pscustomobject]@{ PlaybackStatus = 'Playing'; PlaybackRate = 1.5 }
if ((Get-MediaPosition $timeline $playback $now) -ne 26) { throw 'Playback rate interpolation failed' }
$playback.PlaybackStatus = 'Paused'
if ((Get-MediaPosition $timeline $playback $now) -ne 20) { throw 'Paused position moved' }
Write-Output 'Media time, seek limits, playback rate and pause tests passed.'
if ($Probe) {
    $task = ConvertTo-MediaTask ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])
    if (-not $task.Wait(5000)) { throw 'Media manager request timed out' }
    foreach ($session in $task.Result.GetSessions()) {
        $info = $session.GetPlaybackInfo()
        $line = $session.GetTimelineProperties()
        [pscustomobject]@{ App = $session.SourceAppUserModelId; Status = $info.PlaybackStatus.ToString(); Seek = $info.Controls.IsPlaybackPositionEnabled; Pause = $info.Controls.IsPauseEnabled; Position = $line.Position.TotalSeconds; Duration = $line.EndTime.TotalSeconds; MinSeek = $line.MinSeekTime.TotalSeconds; MaxSeek = $line.MaxSeekTime.TotalSeconds }
    }
}
