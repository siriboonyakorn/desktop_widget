$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ClockWidget.ps1') -Preview
$oldPath = $script:macDockSettingsPath
$script:macDockSettingsPath = Join-Path $PSScriptRoot ('test-pins-' + [Guid]::NewGuid().ToString('N') + '.json')
try {
    $before = @($script:macDockPaths)
    $left = @($script:dockPaths)
    $candidate = Join-Path $env:WINDIR 'System32\notepad.exe'
    if ($candidate -in $before) { $candidate = Join-Path $env:WINDIR 'System32\cmd.exe' }
    if (-not (Add-MacDockShortcut $candidate)) { throw 'Append failed.' }
    if ($script:macDockPaths.Count -ne ($before.Count + 1) -or ($script:macDockPaths[0..($before.Count-1)] -join '|') -ne ($before -join '|')) { throw 'Existing pins changed.' }
    $saved = Get-Content $script:macDockSettingsPath -Raw | ConvertFrom-Json
    if ($saved.shortcuts[-1] -ne $candidate) { throw 'New app did not persist.' }
    $panel = $macDockWindow.FindName('MacDockButtons')
    if ($panel.Children[$before.Count+1] -ne $script:macDockButtons[-1] -or $panel.Children[$panel.Children.Count-1] -ne $script:macDynamicPanel) { throw 'New app inserted in the wrong place.' }
    if ($script:macPinnedMenu.Items.Count -ne $script:macDockPaths.Count) { throw 'New app is missing from replacement menu.' }
    if (Add-MacDockShortcut $candidate) { throw 'Duplicate pin accepted.' }
    if (Add-MacDockShortcut (Join-Path $PSScriptRoot 'README.md')) { throw 'Non-app file accepted.' }
    Move-MacDockShortcut $before.Count 0
    if ($script:macDockPaths[0] -ne $candidate) { throw 'New app could not be reordered.' }
    if (($left -join '|') -ne ($script:dockPaths -join '|')) { throw 'Left dock changed.' }
    if ($macDockWindow.ContextMenu.Items[0].Header -ne 'Add another app...') { throw 'Add action is not visible.' }
    Write-Output 'Add app: append, persistence, UI insertion, menu, duplicate rejection, validation, reorder and left-dock preservation passed.'
} finally {
    if (Test-Path $script:macDockSettingsPath) { Remove-Item -LiteralPath $script:macDockSettingsPath }
    $script:macDockSettingsPath = $oldPath
    foreach ($entry in $script:cornerCards) { $entry.Window.Close() }
}
