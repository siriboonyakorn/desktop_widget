$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ClockWidget.ps1') -Preview
$helper = $null
$originalPaths = @($script:macDockPaths)
try {
    $title = 'Taskbar verification ' + [Guid]::NewGuid().ToString('N')
    $source = "Add-Type -AssemblyName PresentationFramework; `$w = New-Object Windows.Window; `$w.Title = '$title'; `$w.Width = 320; `$w.Height = 160; `$w.Content = 'Checking taskbar window switching'; `$w2 = New-Object Windows.Window; `$w2.Title = '$title second'; `$w2.Width = 320; `$w2.Height = 160; `$w2.Show(); [void]`$w.ShowDialog()"
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($source))
    $helper = Start-Process powershell.exe -ArgumentList ('-NoProfile -STA -EncodedCommand ' + $encoded) -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::Now.AddSeconds(10)
    do {
        Start-Sleep -Milliseconds 200
        $task = [MacTaskNative]::Tasks() | Where-Object Title -eq $title | Select-Object -First 1
    } until ($task -or [DateTime]::Now -gt $deadline)
    if (-not $task -or -not $task.Path) { throw 'Real app window was not enumerated.' }
    $script:macDockPaths[0] = $task.Path
    $script:macTaskNextPoll = [DateTime]::MinValue; Update-MacDockTasks
    if (-not @($script:macSlotTasks[0] | Where-Object Handle -eq $task.Handle).Count) { throw 'Running app did not match its pinned executable.' }
    [void]$script:macDockButtons[0].ApplyTemplate()
    if ($script:macDockButtons[0].Template.FindName('RunningDot',$script:macDockButtons[0]).Visibility -ne 'Visible') { throw 'Running indicator was not shown.' }
    $macDockWindow.Opacity = 1; $script:macDockEntry.Slide.Y = 0
    $macDockWindow.Show(); $macDockWindow.UpdateLayout()
    $indicator = $script:macDockButtons[0].Template.FindName('RunningDot',$script:macDockButtons[0])
    $origin = $indicator.TranslatePoint([Windows.Point]::new(0,0),$script:macDockButtons[0])
    if ($origin.Y -lt 0 -or $origin.Y + $indicator.ActualHeight -gt $script:macDockButtons[0].ActualHeight) { throw 'Running underline lies outside the button and will be clipped.' }
    $matches = @($script:macSlotTasks[0])
    if ($matches.Count -lt 2) { throw 'Two app windows were not grouped.' }
    $badge = $script:macDockButtons[0].Template.FindName('WindowCount',$script:macDockButtons[0])
    if ($badge.Visibility -ne 'Visible') { throw 'Multiple-window badge missing.' }
    Show-MacWindowPicker $script:macDockButtons[0]
    if (-not $script:macPicker.IsOpen -or $script:macPickerItems.Children.Count -ne ($matches.Count + 1)) { throw 'Picker did not list every window.' }
    $row = @($script:macPickerItems.Children | Where-Object Tag -eq $task.Handle)[0]
    [void][MacTaskNative]::ShowWindowAsync($task.Handle,6)
    Start-Sleep -Milliseconds 250
    $row.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    Start-Sleep -Milliseconds 250
    if ($script:macPicker.IsOpen -or [MacTaskNative]::IsIconic($task.Handle) -or $script:macDockEntry.PickerOpen) { throw 'Picker selection failed to restore the chosen window and dismiss.' }
    $script:macDockPaths[0] = ''
    $script:macTaskNextPoll = [DateTime]::MinValue; Update-MacDockTasks
    $grouped = @($script:macDynamicPanel.Children | Where-Object { @($script:macButtonTasks[$_.GetHashCode()] | Where-Object Handle -eq $task.Handle).Count })
    if ($grouped.Count -ne 1 -or @($script:macButtonTasks[$grouped[0].GetHashCode()]).Count -lt 2) { throw 'Unpinned app windows were not grouped into one button.' }
    if (-not $script:topBarWindow.FindName('TrayStatus')) { throw 'Tray control missing.' }
    [void][MacTaskNative]::ShowWindowAsync($task.Handle,6)
    Start-Sleep -Milliseconds 250
    if (-not [MacTaskNative]::IsIconic($task.Handle)) { throw 'Test window did not minimize.' }
    [MacTaskNative]::Activate($task.Handle)
    Start-Sleep -Milliseconds 250
    if ([MacTaskNative]::IsIconic($task.Handle)) { throw 'Taskbar failed to restore a minimized window.' }
    if ([MacTaskNative]::IsFullscreen($task.Handle)) { throw 'Normal app incorrectly treated as fullscreen.' }
    Start-CornerWidgets
    Update-CornerHover
    if ($script:macDockEntry.Visible -or -not $macDockWindow.Topmost -or -not $topBarWindow.Topmost) { throw 'Taskbar must remain hidden over apps until edge dwell.' }
    $script:macDockEntry.Enabled = $false
    Update-CornerHover
    if ($script:macDockEntry.Visible -or -not ([DesktopHost]::GetWindowLong($script:macDockEntry.Handle,-20) -band 0x20)) { throw 'Disabled taskbar must be hidden and click-through.' }
    if ($script:dockEntry.Anchor -ne 'LeftCenter' -or $script:dockEntry.Overlay) { throw 'Original left dock behavior changed.' }
    Write-Output 'Two-window grouping, picker selection, count badge, tray control, real window detection, pinned running indicator, minimized restore, app-mode auto-hide, independent disable and left-dock preservation passed.'
} finally {
    if ($helper -and -not $helper.HasExited) { [void]$helper.CloseMainWindow(); if (-not $helper.WaitForExit(3000)) { $helper.Kill() } }
    $script:macDockPaths = $originalPaths
    if ($script:cornerTimer) { $script:cornerTimer.Stop() }
    foreach ($entry in $script:cornerCards) { $entry.Window.Close() }
}
