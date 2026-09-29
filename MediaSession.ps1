# Windows' built-in global media session API. No browser extension is needed.
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager,Windows.Media.Control,ContentType=WindowsRuntime] | Out-Null
[Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties,Windows.Media.Control,ContentType=WindowsRuntime] | Out-Null
$script:asTaskMethod = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetGenericArguments().Count -eq 1 -and
    $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
} | Select-Object -First 1

function ConvertTo-MediaTask($Operation, [Type]$ResultType) {
    return ,$script:asTaskMethod.MakeGenericMethod($ResultType).Invoke($null, @($Operation))
}

function Format-MediaTime([double]$Seconds) {
    $span = [TimeSpan]::FromSeconds([Math]::Max(0, [Math]::Floor($Seconds)))
    if ($span.TotalHours -ge 1) { return '{0}:{1:00}:{2:00}' -f [int][Math]::Floor($span.TotalHours), $span.Minutes, $span.Seconds }
    return '{0}:{1:00}' -f [int][Math]::Floor($span.TotalMinutes), $span.Seconds
}

function Get-MediaPosition($Timeline, $Playback, [DateTimeOffset]$Now = [DateTimeOffset]::Now) {
    $position = $Timeline.Position.TotalSeconds
    if ($Playback.PlaybackStatus.ToString() -eq 'Playing') {
        $rate = if ($null -ne $Playback.PlaybackRate) { [double]$Playback.PlaybackRate } else { 1.0 }
        $elapsed = [Math]::Max(0, ($Now - $Timeline.LastUpdatedTime).TotalSeconds)
        $position += $elapsed * $rate
    }
    return [Math]::Max($Timeline.StartTime.TotalSeconds, [Math]::Min($Timeline.EndTime.TotalSeconds, $position))
}

function Limit-MediaSeek([double]$Position, [double]$Start, [double]$End) {
    return [Math]::Max($Start, [Math]::Min($End, $Position))
}
