param([switch]$Live)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ClockWidget.ps1') -Preview
if ((Get-WeatherDescription 0) -ne 'Clear sky' -or (Get-WeatherDescription 95) -ne 'Thunderstorms' -or (Get-WeatherDescription 999) -ne 'Conditions unavailable') { throw 'Weather code mapping failed' }
$weatherEntry = $script:cornerCards | Where-Object Name -eq 'Weather'
if ($weatherEntry.Anchor -ne 'Right' -or $weatherEntry.Visible) { throw 'Weather card anchor or initial visibility failed' }
if ($Live) {
    $Preview = $false
    $script:weatherClient = [Net.Http.HttpClient]::new()
    $script:weatherClient.Timeout = [TimeSpan]::FromSeconds(15)
    try {
        Update-Weather
        for ($i = 0; $i -lt 80 -and -not $script:weatherLastUpdated -and -not $script:weatherError; $i++) {
            Start-Sleep -Milliseconds 250
            Update-Weather
        }
        if (-not $script:weatherLastUpdated) { throw "Live weather did not load: $script:weatherError" }
        Write-Output "$($weatherTemperature.Text) $($weatherCondition.Text); $($weatherUpdated.Text)"
        $bangkok=[TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::UtcNow,'SE Asia Standard Time')
        $scene=Get-DaylightState $bangkok $script:weatherData
        if ($scene.Estimated) { throw 'Live sunrise/sunset fields are missing or stale' }
        Write-Output "Live daylight: $($scene.Detail)"
        Save-CornerPreview
    } finally { $script:weatherClient.Dispose() }
}
Write-Output 'Weather mapping and top-right placement checks passed.'
