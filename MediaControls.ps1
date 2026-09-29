. (Join-Path $PSScriptRoot 'MediaSession.ps1')
$mediaPanel = $window.FindName('MediaPanel')
$mediaTitle = $window.FindName('MediaTitle')
$mediaSeek = $window.FindName('MediaSeek')
$mediaElapsed = $window.FindName('MediaElapsed')
$mediaDuration = $window.FindName('MediaDuration')
$mediaBack = $window.FindName('MediaBack')
$mediaPlay = $window.FindName('MediaPlay')
$mediaForward = $window.FindName('MediaForward')
$script:mediaManager = $null
$script:mediaSession = $null
$script:managerTask = $null
$script:metadataTask = $null
$script:commandTask = $null
$script:draggingSeek = $false
$script:dragSession = $null
$script:mediaPosition = 0.0
$script:titlePoll = [DateTime]::MinValue
$script:mediaMessageUntil = [DateTime]::MinValue

function Start-Media {
    try {
        $script:managerTask = ConvertTo-MediaTask ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])
    } catch { $mediaTitle.Text = 'Media controls unavailable' }
}

function Set-MediaIdle([string]$Message) {
    $mediaTitle.Text = $Message
    $mediaSeek.IsEnabled = $false
    $mediaBack.IsEnabled = $false
    $mediaForward.IsEnabled = $false
    $mediaPlay.IsEnabled = $false
    $mediaPlay.Content = 'Play'
    $mediaElapsed.Text = '--:--'
    $mediaDuration.Text = '--:--'
    $mediaSeek.Value = 0
    $script:draggingSeek = $false
}

function Update-Media {
    if ($Preview) { return }
    try {
        if ($script:managerTask -and $script:managerTask.IsCompleted) {
            if ($script:managerTask.IsFaulted -or $script:managerTask.IsCanceled) {
                Set-MediaIdle 'Media controls unavailable'
            } else { $script:mediaManager = $script:managerTask.Result }
            $script:managerTask = $null
        }
        if (-not $script:mediaManager) { return }
        $current = $script:mediaManager.GetCurrentSession()
        if (-not $current) {
            $script:mediaSession = $null
            $script:metadataTask = $null
            Set-MediaIdle 'Play a video to connect'
            return
        }
        if (-not [object]::ReferenceEquals($current, $script:mediaSession)) {
            $script:mediaSession = $current
            $script:metadataTask = $null
            $script:commandTask = $null
            $script:titlePoll = [DateTime]::MinValue
            $script:mediaMessageUntil = [DateTime]::MinValue
            $script:draggingSeek = $false
            $mediaTitle.Text = $current.SourceAppUserModelId
        }
        if ($script:commandTask) {
            if ($script:commandTask.IsCompleted) {
                if ($script:commandTask.IsFaulted -or $script:commandTask.IsCanceled -or -not $script:commandTask.Result) {
                    $mediaTitle.Text = 'This player could not apply that control'
                    $script:mediaMessageUntil = [DateTime]::Now.AddSeconds(4)
                }
                $script:commandTask = $null
            } elseif ([DateTime]::Now -gt $script:commandDeadline) {
                $script:commandTask = $null
                $mediaTitle.Text = 'The player did not respond'
                $script:mediaMessageUntil = [DateTime]::Now.AddSeconds(4)
            }
        }
        $info = $current.GetPlaybackInfo()
        $line = $current.GetTimelineProperties()
        $script:mediaPosition = Get-MediaPosition $line $info
        $hasDuration = $line.EndTime -gt $line.StartTime
        $seekStart = [Math]::Max($line.StartTime.TotalSeconds, $line.MinSeekTime.TotalSeconds)
        $seekEnd = [Math]::Min($line.EndTime.TotalSeconds, $line.MaxSeekTime.TotalSeconds)
        $canSeek = $hasDuration -and $seekEnd -gt $seekStart -and $info.Controls.IsPlaybackPositionEnabled -and -not $script:commandTask
        $mediaSeek.IsEnabled = $canSeek
        $mediaBack.IsEnabled = $canSeek
        $mediaForward.IsEnabled = $canSeek
        $isPlaying = $info.PlaybackStatus.ToString() -eq 'Playing'
        $mediaPlay.Content = if ($isPlaying) { 'Pause' } else { 'Play' }
        $mediaPlay.IsEnabled = -not $script:commandTask -and $(if ($isPlaying) { $info.Controls.IsPauseEnabled } else { $info.Controls.IsPlayEnabled })
        if (-not $script:draggingSeek) {
            $mediaSeek.Minimum = $line.StartTime.TotalSeconds
            $mediaSeek.Maximum = [Math]::Max($mediaSeek.Minimum + 1, $line.EndTime.TotalSeconds)
            $mediaSeek.Value = $script:mediaPosition
            $mediaElapsed.Text = if ($hasDuration) { Format-MediaTime ($script:mediaPosition - $line.StartTime.TotalSeconds) } else { '--:--' }
        }
        $mediaDuration.Text = if ($hasDuration) { Format-MediaTime ($line.EndTime - $line.StartTime).TotalSeconds } else { 'LIVE / unknown' }
        $mediaSeek.ToolTip = if ($canSeek) { 'Drag or click to seek' } else { 'This player does not expose a seekable timeline' }
        if ($script:metadataTask -and $script:metadataTask.IsCompleted) {
            if (-not $script:metadataTask.IsFaulted -and -not $script:metadataTask.IsCanceled -and [DateTime]::Now -gt $script:mediaMessageUntil) {
                $title = $script:metadataTask.Result.Title
                $mediaTitle.Text = if ($title) { $title } else { $current.SourceAppUserModelId }
                $mediaTitle.ToolTip = $mediaTitle.Text
            }
            $script:metadataTask = $null
        }
        if (-not $script:metadataTask -and [DateTime]::Now -ge $script:titlePoll) {
            $script:metadataTask = ConvertTo-MediaTask ($current.TryGetMediaPropertiesAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties])
            $script:titlePoll = [DateTime]::Now.AddSeconds(3)
        }
    } catch {
        $script:mediaSession = $null
        Set-MediaIdle 'Waiting for your media player'
    }
}

function Send-MediaCommand([string]$Command, [double]$Seconds = 0) {
    if (-not $script:mediaSession -or $script:commandTask) { return }
    try {
        # Never send a stale drag/click to a newly selected player.
        if (-not [object]::ReferenceEquals($script:mediaSession, $script:mediaManager.GetCurrentSession())) { return }
        $info = $script:mediaSession.GetPlaybackInfo()
        if ($Command -eq 'Seek') {
            if (-not $info.Controls.IsPlaybackPositionEnabled) { return }
            $line = $script:mediaSession.GetTimelineProperties()
            $minimum = [Math]::Max($line.StartTime.TotalSeconds, $line.MinSeekTime.TotalSeconds)
            $maximum = [Math]::Min($line.EndTime.TotalSeconds, $line.MaxSeekTime.TotalSeconds)
            if ($maximum -le $minimum) { return }
            $target = Limit-MediaSeek $Seconds $minimum $maximum
            $operation = $script:mediaSession.TryChangePlaybackPositionAsync([TimeSpan]::FromSeconds($target).Ticks)
        } elseif ($info.PlaybackStatus.ToString() -eq 'Playing') {
            $operation = $script:mediaSession.TryPauseAsync()
        } else { $operation = $script:mediaSession.TryPlayAsync() }
        $script:commandTask = ConvertTo-MediaTask $operation ([bool])
        $script:commandDeadline = [DateTime]::Now.AddSeconds(5)
        Update-Media
    } catch {
        $mediaTitle.Text = 'This player could not apply that control'
        $script:mediaMessageUntil = [DateTime]::Now.AddSeconds(4)
    }
}
$mediaPlay.Add_Click({ Send-MediaCommand 'Toggle' })
$mediaBack.Add_Click({ Send-MediaCommand 'Seek' ($script:mediaPosition - 10) })
$mediaForward.Add_Click({ Send-MediaCommand 'Seek' ($script:mediaPosition + 10) })
$mediaSeek.Add_PreviewMouseLeftButtonDown({
    if ($mediaSeek.IsEnabled) { $script:draggingSeek = $true; $script:dragSession = $script:mediaSession }
})
$mediaSeek.Add_ValueChanged({
    if ($script:draggingSeek) { $mediaElapsed.Text = Format-MediaTime ($mediaSeek.Value - $mediaSeek.Minimum) }
})
function Complete-MediaDrag {
    if (-not $script:draggingSeek) { return }
    $script:draggingSeek = $false
    if ([object]::ReferenceEquals($script:dragSession, $script:mediaSession)) { Send-MediaCommand 'Seek' $mediaSeek.Value }
}
$mediaSeek.Add_PreviewMouseLeftButtonUp({ Complete-MediaDrag })
$mediaSeek.Add_LostMouseCapture({ Complete-MediaDrag })
$mediaSeek.Add_PreviewKeyUp({ param($sender, $args)
    if ($args.Key.ToString() -in @('Left','Right','Home','End','PageUp','PageDown')) { Send-MediaCommand 'Seek' $mediaSeek.Value }
})
