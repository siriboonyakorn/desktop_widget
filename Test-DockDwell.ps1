$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ClockWidget.ps1') -Preview
try {
    $card = @{ Pinned = $true; Visible = $true; LastNear = [DateTime]::MinValue }
    $now = [DateTime]::Now
    if (-not (Test-MacDockReveal $card $true $false $false $false $now)) { throw 'Desktop pin behavior changed.' }
    if (Test-MacDockReveal $card $false $false $true $false $now) { throw 'App must hide dock even when pinned or near its old position.' }
    if (Test-MacDockReveal $card $false $true $false $false $now) { throw 'Edge revealed immediately.' }
    if (Test-MacDockReveal $card $false $true $false $false $now.AddMilliseconds(999)) { throw 'Edge revealed too soon.' }
    if (-not (Test-MacDockReveal $card $false $true $false $false $now.AddMilliseconds(1000))) { throw 'One-second edge dwell failed.' }
    if (-not (Test-MacDockReveal $card $false $false $true $false $now.AddMilliseconds(1200))) { throw 'Moving from edge into dock hid it.' }
    if (Test-MacDockReveal $card $false $false $false $false $now.AddSeconds(5)) { throw 'Leaving dock did not hide it.' }
    [void](Test-MacDockReveal $card $false $true $false $false $now.AddSeconds(6))
    [void](Test-MacDockReveal $card $false $false $false $false $now.AddMilliseconds(6500))
    if (Test-MacDockReveal $card $false $true $false $false $now.AddSeconds(7)) { throw 'Leaving edge did not reset timer.' }
    if (-not (Test-MacDockReveal $card $false $false $false $true $now.AddSeconds(8))) { throw 'Menu interaction did not keep dock open.' }
    if (-not (Test-MacDockReveal $card $true $false $false $false $now.AddSeconds(9))) { throw 'Returning to desktop did not restore pin behavior.' }
    if (Test-MacDockReveal $card $false $false $false $false $now.AddSeconds(10)) { throw 'Re-entering app bypassed dwell.' }
    Write-Output 'Desktop behavior, app-only dwell, one-second threshold, pointer transfer, hide delay, timer reset and menu interaction passed.'
} finally { foreach ($entry in $script:cornerCards) { $entry.Window.Close() } }
