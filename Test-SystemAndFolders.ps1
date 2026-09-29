$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ClockWidget.ps1') -Preview
$before = @{ Idle = 100; Kernel = 200; User = 100 }
$after = @{ Idle = 140; Kernel = 260; User = 140 }
if ((Get-WidgetCpuPercent $before $after) -ne 60) { throw 'CPU calculation must subtract idle from kernel + user time' }
if ($null -ne (Get-WidgetCpuPercent $null $after) -or $null -ne (Get-WidgetCpuPercent $before $before)) { throw 'First/zero-duration CPU samples must be unavailable' }
if ($null -ne (Get-WidgetCpuPercent $after $before)) { throw 'Counter reset must not report a percentage' }
Update-SystemMonitor
Start-Sleep -Milliseconds 250
$script:monitorNextPoll = [DateTime]::MinValue
Update-SystemMonitor
foreach ($name in @('CPU','RAM','DISK')) {
    if ($script:monitorMetrics[$name].Value.Text -notmatch '^\d+%$' -or $script:monitorMetrics[$name].Bar.Width -lt 0 -or $script:monitorMetrics[$name].Bar.Width -gt 70) { throw "Live $name reading invalid" }
}
$monitor = $script:cornerCards | Where-Object Name -eq 'SystemMonitor'
$normal = [Windows.Rect]::new(0,0,1920,1040)
$point = Get-WidgetPlacement $monitor $normal
if ($point.X -ne 811 -or $point.Y -ne (2 + $topBarWindow.Height)) { throw 'Monitor must be top center below menu bar' }
$point = Get-WidgetPlacement $script:folderEntry $normal
if ($point.X -ne 1846 -or $point.Y -lt 486) { throw 'Folder dock should be on right below note' }
$small = [Windows.Rect]::new(0,0,1280,680)
$smallPoint = Get-WidgetPlacement $script:folderEntry $small
if ($smallPoint.X + $folderWindow.Width -gt ($small.Right - $noteWindow.Width - 10) -or $smallPoint.Y + $folderWindow.Height -gt $small.Bottom) { throw 'Folder dock should avoid the note on shorter screens' }
if ($script:folderButtons.Count -ne 4 -or $script:quickFolderPaths.Count -ne 4) { throw 'Folder slots missing' }
$originalPaths = @($script:quickFolderPaths)
$originalSettings = $script:folderSettingsPath
$script:folderSettingsPath = Join-Path $PSScriptRoot ('test-folders-' + [Guid]::NewGuid().ToString('N') + '.json')
try {
    Set-QuickFolder 0 $PSScriptRoot
    $saved = Get-Content -LiteralPath $script:folderSettingsPath -Raw | ConvertFrom-Json
    if ($saved.folders[0] -ne $PSScriptRoot) { throw 'Folder choice did not persist' }
    $rejected = $false
    try { Set-QuickFolder 0 (Join-Path $PSScriptRoot 'ClockWidget.ps1') } catch { $rejected = $true }
    if (-not $rejected) { throw 'Quick folders must reject executable/file paths' }
    Start-CornerWidgets
    foreach ($entry in @($monitor,$script:folderEntry)) {
        Set-CornerVisible $true $entry
        if ([DesktopHost]::GetWindowLong($entry.Handle,-20) -band 0x20) { throw 'Visible new widgets must accept clicks' }
        Set-CornerVisible $false $entry
        if (-not ([DesktopHost]::GetWindowLong($entry.Handle,-20) -band 0x20)) { throw 'Hidden new widgets must pass clicks through' }
    }
    if ($script:folderEntry.Slide.Y -ne 0) { throw 'Folder dock should slide horizontally' }
    Write-Output 'CPU delta and live metrics, top-center placement, folder collision avoidance, persistence, file rejection and click-through checks passed.'
    Write-Output ('Live readings: CPU {0}, RAM {1}, disk {2}' -f $monitorMetrics.CPU.Value.Text,$monitorMetrics.RAM.Value.Text,$monitorMetrics.DISK.Value.Text)
} finally {
    if ($script:cornerTimer) { $script:cornerTimer.Stop() }
    foreach ($entry in $script:cornerCards) { $entry.Window.Close() }
    if (Test-Path -LiteralPath $script:folderSettingsPath) { Remove-Item -LiteralPath $script:folderSettingsPath }
    $script:folderSettingsPath = $originalSettings
    $script:quickFolderPaths = $originalPaths
}
