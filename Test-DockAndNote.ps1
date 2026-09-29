$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ClockWidget.ps1') -Preview
$originalDockPaths = @($script:dockPaths)
$originalDockSettings = $script:dockSettingsPath
$originalNotePath = $script:notePath
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('WidgetTests-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
try {
    if ($window.Height -ne 370 -or $window.FindName('NotificationHost')) { throw 'Notification placeholder still present' }
    $script:dockSettingsPath = Join-Path $testRoot 'dock.json'
    $script:dockPaths = @('a','b','c','d','e')
    Move-DockShortcut 0 3
    if (($script:dockPaths -join ',') -ne 'b,c,d,a,e') { throw 'Dragging down should insert and shift other shortcuts' }
    Move-DockShortcut 4 0
    if (($script:dockPaths -join ',') -ne 'e,b,c,d,a') { throw 'Dragging up should insert and shift other shortcuts' }
    $persisted = Get-Content -LiteralPath $script:dockSettingsPath -Raw | ConvertFrom-Json
    if (($persisted.shortcuts -join ',') -ne 'e,b,c,d,a') { throw 'Reordered shortcuts did not persist' }
    Move-DockShortcut -1 6
    if (($script:dockPaths -join ',') -ne 'e,b,c,d,a') { throw 'Invalid drop changed shortcuts' }
    $script:dockSuppressClick = $true
    $script:dockButtons[0].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    if ($script:dockSuppressClick) { throw 'Post-drag click guard did not run' }

    $script:notePath = Join-Path $testRoot 'note.txt'
    $Preview = $false
    $noteEditor.Text = "First line`r`nSecond line " + [char]0x0E01
    if (-not $script:noteDirty) { throw 'Typing must mark note unsaved' }
    Save-QuickNote
    if ($script:noteDirty -or [IO.File]::ReadAllText($script:notePath) -ne $noteEditor.Text) { throw 'First Unicode note save failed' }
    $noteEditor.Text = 'Updated text'
    Save-QuickNote
    if ([IO.File]::ReadAllText($script:notePath) -ne 'Updated text') { throw "Atomic update failed: $($noteStatus.ToolTip)" }
    $noteEditor.Text = ''
    Save-QuickNote
    if ([IO.File]::ReadAllText($script:notePath).Length -ne 0) { throw 'Clearing note did not persist' }
    if ($noteWindow.FindName('NotePlaceholder').Visibility -ne 'Visible') { throw 'Empty note needs placeholder' }
    $script:notePath = Join-Path $testRoot 'missing\note.txt'
    $noteEditor.Text = 'Keep unsaved text'
    Save-QuickNote
    if (-not $script:noteDirty -or $noteEditor.Text -ne 'Keep unsaved text' -or $noteStatus.Text -notlike 'Not saved*') { throw 'Save failure must preserve text and report unsaved state' }
    Write-Output 'Dock reordering, persistence, drag-click guard, Unicode note saves, atomic updates, empty notes, save-failure retention and notification removal passed.'
} finally {
    $Preview = $true
    $script:noteSaveTimer.Stop()
    $script:dockPaths = $originalDockPaths
    $script:dockSettingsPath = $originalDockSettings
    $script:notePath = $originalNotePath
    # Only remove the exact test files created in this unique temporary folder.
    foreach ($name in @('dock.json','note.txt','note.txt.tmp')) {
        $path = Join-Path $testRoot $name
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path }
    }
    Remove-Item -LiteralPath $testRoot
}
