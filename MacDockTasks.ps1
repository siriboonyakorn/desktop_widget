# Track actual top-level app windows, separately from the original shortcut dock.
$script:macTaskNextPoll = [DateTime]::MinValue
$script:macTaskTargets = @{}
$script:macSlotTasks = @{}
$script:macTasks = @()
$script:macDynamicKey = ''
$script:macButtonTasks = @{}
$script:macDynamicPanel = [Windows.Controls.StackPanel]::new()
$macDynamicPanel.Orientation = 'Horizontal'
[void]$macDockWindow.FindName('MacDockButtons').Children.Add($macDynamicPanel)
$script:macWindowsMenu = [Windows.Controls.MenuItem]::new()
$macWindowsMenu.Header = 'Open windows'
[void]$macDockWindow.ContextMenu.Items.Add($macWindowsMenu)
$macDockWindow.ContextMenu.Add_Opened({
    $script:macWindowsMenu.Items.Clear()
    foreach ($task in @([MacTaskNative]::Tasks())) {
        $item = [Windows.Controls.MenuItem]::new(); $item.Header = $task.Title; $item.Tag = $task.Handle
        $item.Add_Click({ param($sender,$e) [MacTaskNative]::Activate([IntPtr]$sender.Tag) })
        [void]$script:macWindowsMenu.Items.Add($item)
    }
    if (-not $script:macWindowsMenu.Items.Count) { $item = [Windows.Controls.MenuItem]::new(); $item.Header = 'No open windows'; $item.IsEnabled = $false; [void]$script:macWindowsMenu.Items.Add($item) }
    $script:macDockEntry.Configuring = $true
})
$macDockWindow.ContextMenu.Add_Closed({ $script:macDockEntry.Configuring = $false; $script:macDockEntry.LastNear = [DateTime]::Now })
$macDockWindow.FindName('MacDockScroll').Add_PreviewMouseWheel({
    param($sender,$e)
    $sender.ScrollToHorizontalOffset($sender.HorizontalOffset - $e.Delta)
    $e.Handled = $true
})
# One animation clock follows the latest pointer position, including fast crossings.
$script:macMotionClock = [Diagnostics.Stopwatch]::StartNew()
$script:macMotionLast = 0.0
$script:macMotionTimer = [Windows.Threading.DispatcherTimer]::new()
$macMotionTimer.Interval = [TimeSpan]::FromMilliseconds(16)
$macMotionTimer.Add_Tick({
    $now = $script:macMotionClock.Elapsed.TotalSeconds
    $dt = [Math]::Min(0.05, $now - $script:macMotionLast); $script:macMotionLast = $now
    $hover = $script:macDockWindow.IsMouseOver -and -not $script:macDockEntry.Configuring -and $script:widgetPreferences.motion
    $point = [Windows.Input.Mouse]::GetPosition($script:macDockWindow)
    $settled = $true
    foreach ($button in @($script:macDockButtons) + @($script:macDynamicPanel.Children)) {
        if ($button.Content -isnot [Windows.Controls.Image]) { continue }
        $target = 1.0
        if ($hover) {
            $center = $button.TranslatePoint([Windows.Point]::new($button.ActualWidth / 2,0),$script:macDockWindow)
            $target += [Math]::Exp(-[Math]::Pow(($point.X - $center.X) / 64,2))
        }
        $transform = $button.Content.RenderTransform
        $value = $transform.ScaleX + ($target - $transform.ScaleX) * (1 - [Math]::Exp(-$dt / 0.075))
        if (-not $script:widgetPreferences.motion -or [Math]::Abs($target - $value) -lt 0.001) { $value = $target } else { $settled = $false }
        $transform.ScaleX = $value; $transform.ScaleY = $value
    }
    if (-not $hover -and $settled) { $script:macMotionTimer.Stop() }
})
$macDockWindow.Add_MouseMove({
    if (-not $script:macMotionTimer.IsEnabled) {
        $script:macMotionLast = $script:macMotionClock.Elapsed.TotalSeconds
        $script:macMotionTimer.Start()
    }
})
$macDockWindow.Add_Closed({ $script:macMotionTimer.Stop() })

function Get-MacDockTarget([string]$Path) {
    if (-not $Path) { return '' }
    if ($script:macTaskTargets.ContainsKey($Path)) { return $script:macTaskTargets[$Path] }
    $target = $Path
    if ([IO.Path]::GetExtension($Path) -eq '.lnk') {
        $shell = $null; $shortcut = $null
        try {
            $shell = New-Object -ComObject WScript.Shell
            $shortcut = $shell.CreateShortcut($Path); $target = [string]$shortcut.TargetPath
        } catch { $target = '' }
        finally {
            if ($shortcut) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shortcut) }
            if ($shell) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell) }
        }
    }
    $script:macTaskTargets[$Path] = $target
    return $target
}
function Activate-MacDockSlot([int]$Slot) {
    $script:macTaskNextPoll = [DateTime]::MinValue; Update-MacDockTasks
    $matches = @($script:macSlotTasks[$Slot])
    if ($matches.Count -gt 1) { Show-MacWindowPicker $script:macDockButtons[$Slot]; return $true }
    if ($matches.Count -and $matches[0]) {
        # Rotate the matching windows so repeated clicks cycle through the app.
        $foreground = [CornerNative]::GetForegroundWindow()
        $chosen = $matches[0]
        for ($i=0; $i -lt $matches.Count; $i++) { if ($matches[$i].Handle -eq $foreground) { $chosen = $matches[($i+1) % $matches.Count]; break } }
        [MacTaskNative]::Activate($chosen.Handle)
        return $true
    }
    return $false
}
function Update-MacDockTasks {
    if ([DateTime]::Now -lt $script:macTaskNextPoll -or $script:macDockEntry.Configuring -or -not $script:macDockEntry.BaseWidth) { return }
    $script:macTaskNextPoll = [DateTime]::Now.AddSeconds(2)
    Update-WindowsTaskbar
    $script:macTasks = @([MacTaskNative]::Tasks())
    $pinnedPaths = @()
    for ($slot=0; $slot -lt $script:macDockPaths.Count; $slot++) {
        $target = Get-MacDockTarget $script:macDockPaths[$slot]
        $pinnedPaths += $target
        $matches = @($script:macTasks | Where-Object { $target -and $_.Path -and $_.Path -eq $target })
        $script:macSlotTasks[$slot] = $matches
        $button = $script:macDockButtons[$slot]; [void]$button.ApplyTemplate()
        $dot = $button.Template.FindName('RunningDot',$button)
        Set-MacTaskIndicator $button $matches
    }
    $other = @($script:macTasks | Where-Object { -not $_.Path -or $_.Path -notin $pinnedPaths } | Group-Object { if ($_.Path) { $_.Path.ToLowerInvariant() } else { $_.Name } })
    $key = ($other | ForEach-Object { $_.Name + (($_.Group | ForEach-Object { $_.Handle.ToString() + $_.Title }) -join ',') }) -join '|'
    if ($key -eq $script:macDynamicKey) {
        foreach ($button in @($script:macDynamicPanel.Children)) { Set-MacTaskIndicator $button @($script:macButtonTasks[$button.GetHashCode()]) }
        Expand-MacDockIcons; return
    }
    $script:macDynamicKey = $key
    foreach ($old in @($script:macDynamicPanel.Children)) { $script:macButtonTasks.Remove($old.GetHashCode()) }
    $script:macDynamicPanel.Children.Clear()
    foreach ($group in $other) {
        $task = $group.Group[0]
        $button = [Windows.Controls.Button]::new(); $button.Style = $script:macDockIconStyle
        $button.Width = 56; $button.Height = 54; $button.Margin = [Windows.Thickness]::new(2,0,2,0)
        $button.Tag = $task.Handle; $button.ToolTip = $task.Title
        $button.Content = $task.Name.Substring(0,1).ToUpperInvariant()
        if ($task.Path) {
            $bitmap = [DockNative]::LargeIconFor($task.Path)
            if ($bitmap -ne [IntPtr]::Zero) {
                try {
                    $source = [Windows.Interop.Imaging]::CreateBitmapSourceFromHBitmap($bitmap,[IntPtr]::Zero,[Windows.Int32Rect]::Empty,[Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions())
                    $source.Freeze(); $icon = [Windows.Controls.Image]::new(); $icon.Source = $source
                    $icon.Width = 40; $icon.Height = 40; $icon.RenderTransformOrigin = [Windows.Point]::new(0.5,1)
                    $icon.RenderTransform = [Windows.Media.ScaleTransform]::new(1,1)
                    [Windows.Media.RenderOptions]::SetBitmapScalingMode($icon,'HighQuality'); $button.Content = $icon
                } finally { [void][DockNative]::DeleteObject($bitmap) }
            }
        }
        [Windows.Controls.ToolTipService]::SetPlacement($button,'Top')
        $button.Add_Click({ param($sender,$e) $matches = @($script:macButtonTasks[$sender.GetHashCode()]); if ($matches.Count -gt 1) { Show-MacWindowPicker $sender } elseif ($matches.Count) { [MacTaskNative]::Activate($matches[0].Handle) } })
        $button.Add_MouseEnter({ param($sender,$e) Set-MacDockHover $sender $true; Request-MacWindowPicker $sender })
        $button.Add_MouseLeave({ param($sender,$e) Set-MacDockHover $sender $false })
        [void]$script:macDynamicPanel.Children.Add($button)
        Set-MacTaskIndicator $button @($group.Group)
    }
    Expand-MacDockIcons
}

function Expand-MacDockIcons {
    $buttons = @($script:macStartButton) + @($script:macDockButtons | Where-Object Visibility -eq 'Visible') + @($script:macDynamicPanel.Children)
    if (-not $buttons.Count) { return }
    $scale = $script:widgetPreferences.widgets.MacDock.scale
    $slotWidth = [Math]::Max(60, ($macDockWindow.Width - 60) / ($scale * $buttons.Count))
    foreach ($button in $buttons) { $button.Width = $slotWidth - 4 }
}

# A delayed, interactive popup keeps all windows of an executable together.
function Set-MacTaskIndicator($Button, $Tasks) {
    $items = @($Tasks)
    $script:macButtonTasks[$Button.GetHashCode()] = $items
    [void]$Button.ApplyTemplate()
    $line = $Button.Template.FindName('RunningDot',$Button)
    $line.Visibility = if ($items.Count) { 'Visible' } else { 'Collapsed' }
    $active = @($items | Where-Object Handle -eq ([CornerNative]::GetForegroundWindow())).Count -gt 0
    $line.Width = if ($active) { 30 } else { 22 }
    $line.Fill = [Windows.Media.BrushConverter]::new().ConvertFromString($(if ($active) { '#67C8FF' } else { '#E6FFFFFF' }))
    $badge = $Button.Template.FindName('WindowCount',$Button)
    $badge.Visibility = if ($items.Count -gt 1) { 'Visible' } else { 'Collapsed' }
    $Button.Template.FindName('WindowCountText',$Button).Text = [string]$items.Count
    [Windows.Controls.ToolTipService]::SetIsEnabled($Button,($items.Count -lt 2))
}
$script:macPicker = [Windows.Controls.Primitives.Popup]::new()
$macPicker.Placement = 'Top'; $macPicker.AllowsTransparency = $true; $macPicker.StaysOpen = $true
$macPicker.VerticalOffset = -8
$pickerBorder = [Windows.Controls.Border]::new()
$pickerBorder.Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#F2222C3B')
$pickerBorder.BorderBrush = [Windows.Media.BrushConverter]::new().ConvertFromString('#667FA4BF')
$pickerBorder.BorderThickness = [Windows.Thickness]::new(1); $pickerBorder.CornerRadius = [Windows.CornerRadius]::new(14)
$pickerBorder.Padding = [Windows.Thickness]::new(10)
$pickerScroll = [Windows.Controls.ScrollViewer]::new(); $pickerScroll.MaxHeight = 360; $pickerScroll.VerticalScrollBarVisibility = 'Auto'
$script:macPickerItems = [Windows.Controls.StackPanel]::new()
$pickerScroll.Content = $macPickerItems; $pickerBorder.Child = $pickerScroll; $macPicker.Child = $pickerBorder
$macPicker.Add_Closed({ $script:macDockEntry.PickerOpen = $false; $script:macDockEntry.LastNear = [DateTime]::Now })
function Show-MacWindowPicker($Button) {
    $items = @($script:macButtonTasks[$Button.GetHashCode()])
    if ($items.Count -lt 2) { return }
    $script:macPickerItems.Children.Clear()
    $heading = [Windows.Controls.TextBlock]::new(); $heading.Text = "$($items[0].Name) - $($items.Count) open windows"
    $heading.Foreground = [Windows.Media.Brushes]::LightBlue; $heading.Margin = [Windows.Thickness]::new(8,2,8,8)
    [void]$script:macPickerItems.Children.Add($heading)
    foreach ($task in $items) {
        $row = [Windows.Controls.Button]::new(); $row.Tag = $task.Handle
        $row.Content = $task.Title; $row.ToolTip = $task.Title
        $row.Width = 360; $row.Padding = [Windows.Thickness]::new(10); $row.Margin = [Windows.Thickness]::new(0,2,0,2)
        $row.HorizontalContentAlignment = 'Left'; $row.Foreground = [Windows.Media.Brushes]::White
        $row.Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#FF344459')
        $row.Add_Click({ param($sender,$e) $script:macPicker.IsOpen = $false; $script:macDockEntry.PickerOpen = $false; $script:macDockEntry.LastNear = [DateTime]::Now; [MacTaskNative]::Activate([IntPtr]$sender.Tag) })
        [void]$script:macPickerItems.Children.Add($row)
    }
    $script:macPicker.PlacementTarget = $Button
    $script:macDockEntry.PickerOpen = $true
    $script:macPicker.IsOpen = $true
    $script:macPickerAway = [DateTime]::Now
}
function Request-MacWindowPicker($Button) {
    $script:macPickerCandidate = $Button
    $script:macPickerDue = [DateTime]::Now.AddMilliseconds(400)
}
$script:macPickerTimer = [Windows.Threading.DispatcherTimer]::new()
$macPickerTimer.Interval = [TimeSpan]::FromMilliseconds(100)
$macPickerTimer.Add_Tick({
    if ($script:macPickerCandidate -and [DateTime]::Now -ge $script:macPickerDue) {
        $candidate = $script:macPickerCandidate; $script:macPickerCandidate = $null
        if ($candidate.IsMouseOver -and -not $script:macDockEntry.Configuring -and [Windows.Input.Mouse]::LeftButton -ne 'Pressed') { Show-MacWindowPicker $candidate }
    }
    if ($script:macPicker.IsOpen) {
        if ($script:macPicker.IsMouseOver -or $script:macPicker.PlacementTarget.IsMouseOver) { $script:macPickerAway = [DateTime]::Now }
        elseif (([DateTime]::Now - $script:macPickerAway).TotalMilliseconds -gt 500) { $script:macPicker.IsOpen = $false }
        if (-not $script:macDockEntry.Enabled -or $script:macDockEntry.Configuring) { $script:macPicker.IsOpen = $false }
    }
})
$macPickerTimer.Start()
$macDockWindow.Add_Closed({ $script:macPickerTimer.Stop(); $script:macPicker.IsOpen = $false })
