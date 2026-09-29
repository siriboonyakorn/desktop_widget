function Stop-TaskbarGuard {
    if ($script:taskbarToken -and (Test-Path -LiteralPath $script:taskbarToken)) { Remove-Item -LiteralPath $script:taskbarToken -ErrorAction SilentlyContinue }
    if ($script:taskbarGuard -and -not $script:taskbarGuard.HasExited) { [void]$script:taskbarGuard.WaitForExit(2000) }
    $script:taskbarToken = $null; $script:taskbarGuard = $null
}
function Update-WindowsTaskbar {
    if ($Preview) { return }
    if ($script:trayRevealed) {
        if ([DateTime]::Now -lt $script:trayGrace -or [MacTaskNative]::IsTrayActive()) { return }
        $script:trayRevealed = $false
    }
    if (-not $script:widgetPreferences.hideWindowsTaskbar) { Stop-TaskbarGuard; return }
    if ($script:taskbarGuard -and -not $script:taskbarGuard.HasExited) { return }
    $script:taskbarToken = Join-Path ([IO.Path]::GetTempPath()) ('DesktopWidgetTaskbar-' + [Guid]::NewGuid().ToString('N') + '.token')
    Set-Content -LiteralPath $script:taskbarToken -Value 'Restore taskbar when this file is removed or the widget exits.'
    $guardPath = Join-Path $PSScriptRoot 'TaskbarGuard.ps1'
    $arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}" -ParentId {1} -Token "{2}"' -f $guardPath,$PID,$script:taskbarToken
    $script:taskbarGuard = Start-Process powershell.exe -ArgumentList $arguments -WindowStyle Hidden -PassThru
}

function Show-WidgetSystemTray {
    Stop-TaskbarGuard
    $script:trayRevealed = $true
    $script:trayGrace = [DateTime]::Now.AddSeconds(3)
    [MacTaskNative]::ShowTray()
}
