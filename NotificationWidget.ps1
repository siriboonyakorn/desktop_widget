# Notifications stay in memory and are never written to disk.
[xml]$notificationXaml = @'
<StackPanel xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 TextElement.FontFamily="Segoe UI" TextElement.Foreground="White">
 <Grid Margin="8,0,8,7">
  <TextBlock x:Name="NotificationHeading" Text="NOTIFICATIONS" FontSize="10" Foreground="#C9D8EC" VerticalAlignment="Center"/>
  <Button x:Name="NotificationToggle" Content="Show all" HorizontalAlignment="Right" FontSize="10" Padding="6,2" Background="#20FFFFFF" Foreground="White" BorderThickness="0" Cursor="Hand"/>
 </Grid>
 <Grid x:Name="NotificationStack" Height="112" Background="Transparent" Cursor="Hand" ToolTip="Click or scroll down to see notifications">
  <Border x:Name="NotificationBack2" Margin="20,20,20,0" Height="92" VerticalAlignment="Top" CornerRadius="19" Background="#454E6079" BorderBrush="#30FFFFFF" BorderThickness="1"/>
  <Border x:Name="NotificationBack1" Margin="10,10,10,0" Height="92" VerticalAlignment="Top" CornerRadius="19" Background="#8052637A" BorderBrush="#45FFFFFF" BorderThickness="1"/>
  <ContentControl x:Name="NotificationFront" VerticalAlignment="Top"/>
 </Grid>
 <ScrollViewer x:Name="NotificationScroll" Visibility="Collapsed" MaxHeight="252" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" PanningMode="VerticalOnly" CanContentScroll="False">
  <StackPanel x:Name="NotificationList"/>
 </ScrollViewer>
 <TextBlock x:Name="NotificationHint" Text="" FontSize="10" Foreground="#BBD0EB" HorizontalAlignment="Center" Margin="0,6,0,0"/>
</StackPanel>
'@
$script:notificationRoot = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($notificationXaml))
$window.FindName('NotificationHost').Content = $notificationRoot
$notificationRoot.FindName('NotificationToggle').Style = $cornerTemplate.Resources['Nav']
$script:notificationItems = @()
$script:notificationExpanded = $false
$script:notificationListener = $null
$script:notificationTask = $null
$script:notificationAccessTask = $null
$script:notificationNextPoll = [DateTime]::MinValue
$script:notificationSignature = ''
$script:notificationState = 'Not connected'
$script:notificationDetail = 'Connect Windows notifications to see them here.'
$script:notificationUnavailable = $false

function New-NotificationCard($Item) {
    $card = [Windows.Controls.Border]::new()
    $card.CornerRadius = [Windows.CornerRadius]::new(19)
    $card.BorderThickness = [Windows.Thickness]::new(1)
    $card.BorderBrush = $glassSource.BorderBrush.Clone()
    $card.Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#E0445369')
    $card.Padding = [Windows.Thickness]::new(14,10,14,10)
    $card.MinHeight = 92
    $card.Margin = [Windows.Thickness]::new(0,0,0,7)
    $content = [Windows.Controls.StackPanel]::new()
    $header = [Windows.Controls.Grid]::new()
    $app = [Windows.Controls.TextBlock]::new()
    $app.Text = $Item.App.ToUpperInvariant(); $app.FontSize = 10; $app.Opacity = 0.75
    $app.Margin = [Windows.Thickness]::new(0,0,66,0); $app.TextTrimming = 'CharacterEllipsis'
    $time = [Windows.Controls.TextBlock]::new()
    $time.Text = $Item.Time; $time.FontSize = 10; $time.Opacity = 0.65; $time.HorizontalAlignment = 'Right'
    [void]$header.Children.Add($app); [void]$header.Children.Add($time)
    $title = [Windows.Controls.TextBlock]::new()
    $title.Text = $Item.Title; $title.FontSize = 13; $title.FontWeight = 'SemiBold'
    $title.Margin = [Windows.Thickness]::new(0,4,0,2); $title.TextTrimming = 'CharacterEllipsis'
    $body = [Windows.Controls.TextBlock]::new()
    $body.Text = $Item.Body; $body.FontSize = 12; $body.Opacity = 0.85; $body.TextWrapping = 'Wrap'
    if (-not $script:notificationExpanded) { $body.MaxHeight = 34; $body.TextTrimming = 'CharacterEllipsis' }
    [void]$content.Children.Add($header); [void]$content.Children.Add($title); [void]$content.Children.Add($body)
    $card.Child = $content
    return $card
}

function Render-Notifications {
    $available = [Windows.SystemParameters]::WorkArea.Bottom - $window.Top - 380
    if ([double]::IsNaN($available)) { $available = 252.0 }
    $notificationRoot.FindName('NotificationScroll').MaxHeight = [Math]::Max(100.0, [Math]::Min(252.0, $available))
    $count = $script:notificationItems.Count
    $notificationRoot.FindName('NotificationHeading').Text = if ($count) { "NOTIFICATIONS  /  $count" } else { 'NOTIFICATIONS' }
    $toggle = $notificationRoot.FindName('NotificationToggle')
    $toggle.Content = if (-not $count) { 'Connect' } elseif ($script:notificationExpanded) { 'Stack' } else { 'Show all' }
    $toggle.IsEnabled = $count -gt 0 -or -not $script:notificationUnavailable
    $notificationRoot.FindName('NotificationStack').Visibility = if ($script:notificationExpanded -and $count) { 'Collapsed' } else { 'Visible' }
    $notificationRoot.FindName('NotificationScroll').Visibility = if ($script:notificationExpanded -and $count) { 'Visible' } else { 'Collapsed' }
    $notificationRoot.FindName('NotificationBack1').Visibility = if ($count -gt 1) { 'Visible' } else { 'Collapsed' }
    $notificationRoot.FindName('NotificationBack2').Visibility = if ($count -gt 2) { 'Visible' } else { 'Collapsed' }
    $notificationRoot.FindName('NotificationHint').Text = if ($count -gt 1 -and -not $script:notificationExpanded) { 'Scroll down to see older notifications' } else { '' }
    $list = $notificationRoot.FindName('NotificationList')
    $scroll = $notificationRoot.FindName('NotificationScroll')
    $offset = $scroll.VerticalOffset
    $list.Children.Clear()
    if ($count) {
        $notificationRoot.FindName('NotificationFront').Content = New-NotificationCard $script:notificationItems[0]
        if ($script:notificationExpanded) {
            foreach ($item in $script:notificationItems) { [void]$list.Children.Add((New-NotificationCard $item)) }
        }
    } else {
        $notificationRoot.FindName('NotificationFront').Content = New-NotificationCard @{ App = 'Windows'; Time = ''; Title = $script:notificationState; Body = $script:notificationDetail }
    }
    $scroll.ScrollToVerticalOffset($offset)
}

function Set-NotificationExpanded([bool]$Expanded) {
    $script:notificationExpanded = $Expanded -and $script:notificationItems.Count -gt 0
    Render-Notifications
}

function Connect-Notifications {
    if ($script:notificationAccessTask) { return }
    try {
        $script:notificationAccessTask = ConvertTo-MediaTask ($script:notificationListener.RequestAccessAsync()) ([Windows.UI.Notifications.Management.UserNotificationListenerAccessStatus])
        $script:notificationState = 'Waiting for permission'
        $script:notificationDetail = 'Allow notification access in the Windows prompt.'
    } catch {
        $script:notificationState = 'Connection unavailable'
        $script:notificationDetail = 'Launch the installed Desktop Widget app to connect.'
    }
    Render-Notifications
}

function Start-Notifications {
    try {
        [Windows.UI.Notifications.Management.UserNotificationListener,Windows.UI.Notifications,ContentType=WindowsRuntime] | Out-Null
        [Windows.UI.Notifications.Management.UserNotificationListenerAccessStatus,Windows.UI.Notifications,ContentType=WindowsRuntime] | Out-Null
        [Windows.UI.Notifications.UserNotification,Windows.UI.Notifications,ContentType=WindowsRuntime] | Out-Null
        [Windows.UI.Notifications.NotificationKinds,Windows.UI.Notifications,ContentType=WindowsRuntime] | Out-Null
        $script:notificationListener = [Windows.UI.Notifications.Management.UserNotificationListener]::Current
        [void]$script:notificationListener.GetAccessStatus()
        Update-Notifications
    } catch {
        $script:notificationUnavailable = $true
        $script:notificationState = 'Setup required'
        $script:notificationDetail = 'Windows notification access needs the installed Desktop Widget app.'
        Render-Notifications
    }
}

function Update-Notifications {
    if ($Preview -or -not $script:notificationListener -or $script:notificationUnavailable) { return }
    try {
        if ($script:notificationAccessTask) {
            if (-not $script:notificationAccessTask.IsCompleted) { return }
            $script:notificationAccessTask = $null
            $script:notificationNextPoll = [DateTime]::MinValue
        }
        if ([DateTime]::Now -lt $script:notificationNextPoll) { return }
        $access = $script:notificationListener.GetAccessStatus().ToString()
        if ($access -ne 'Allowed') {
            $script:notificationItems = @(); $script:notificationSignature = ''; $script:notificationTask = $null
            $script:notificationState = 'Notification access needed'
            $script:notificationDetail = if ($access -eq 'Denied') { 'Allow Desktop Widget in Windows notification privacy settings.' } else { 'Click Connect to allow Windows notification access.' }
            Render-Notifications
            $script:notificationNextPoll = [DateTime]::Now.AddSeconds(5)
            return
        }
        if (-not $script:notificationTask) {
            $listType = [System.Collections.Generic.IReadOnlyList``1].MakeGenericType([Windows.UI.Notifications.UserNotification])
            $script:notificationTask = ConvertTo-MediaTask ($script:notificationListener.GetNotificationsAsync([Windows.UI.Notifications.NotificationKinds]::Toast)) $listType
            return
        }
        if (-not $script:notificationTask.IsCompleted) { return }
        if ($script:notificationTask.IsFaulted -or $script:notificationTask.IsCanceled) { throw 'Notification read failed' }
        $items = @(foreach ($notice in ($script:notificationTask.Result | Sort-Object CreationTime -Descending | Select-Object -First 50)) {
            $binding = $notice.Notification.Visual.GetBinding('ToastGeneric')
            if (-not $binding) { continue }
            $texts = @($binding.GetTextElements() | ForEach-Object Text)
            if (-not $texts.Count) { continue }
            @{ Id = $notice.Id; App = $notice.AppInfo.DisplayInfo.DisplayName; Title = $texts[0]; Body = ($texts | Select-Object -Skip 1) -join "`n"; Time = $notice.CreationTime.ToLocalTime().ToString('HH:mm') }
        })
        $script:notificationTask = $null
        $signature = ConvertTo-Json -InputObject $items -Compress
        if ($signature -ne $script:notificationSignature) {
            $script:notificationItems = $items; $script:notificationSignature = $signature
            $script:notificationState = 'No notifications'; $script:notificationDetail = 'New Windows notifications will appear here.'
            Render-Notifications
        }
        $script:notificationNextPoll = [DateTime]::Now.AddSeconds(3)
    } catch {
        $script:notificationTask = $null; $script:notificationItems = @(); $script:notificationSignature = ''
        $script:notificationState = 'Notifications unavailable'; $script:notificationDetail = 'Windows could not provide notifications. Retrying shortly.'
        $script:notificationNextPoll = [DateTime]::Now.AddSeconds(15)
        Render-Notifications
    }
}

$notificationRoot.FindName('NotificationToggle').Add_Click({
    if ($script:notificationItems.Count) { Set-NotificationExpanded (-not $script:notificationExpanded) } else { Connect-Notifications }
})
$notificationRoot.FindName('NotificationStack').Add_MouseLeftButtonUp({ Set-NotificationExpanded $true })
$notificationRoot.FindName('NotificationStack').Add_PreviewMouseWheel({
    param($sender, $eventArgs)
    if ($eventArgs.Delta -lt 0 -and $script:notificationItems.Count) { Set-NotificationExpanded $true; $eventArgs.Handled = $true }
})

function Save-NotificationPreview {
    # Explicit preview fixtures only; never shown by a normal launch.
    $script:notificationItems = @(1..5 | ForEach-Object { @{ App = 'Preview app'; Title = "Sample notification $_"; Body = 'A preview of the scrollable notification stack.'; Time = 'now' } })
    foreach ($expanded in @($false, $true)) {
        Set-NotificationExpanded $expanded
        $window.UpdateLayout()
        # Let template triggers settle before capturing transparent WPF controls.
        [void]$window.Dispatcher.Invoke([Action]{}, [Windows.Threading.DispatcherPriority]::Render)
        $bitmap = [Windows.Media.Imaging.RenderTargetBitmap]::new(1440,1340,192,192,[Windows.Media.PixelFormats]::Pbgra32)
        $bitmap.Render($window)
        $encoder = [Windows.Media.Imaging.PngBitmapEncoder]::new()
        $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
        $name = if ($expanded) { 'preview-notifications-list.png' } else { 'preview-notifications-stack.png' }
        $stream = [IO.File]::Create((Join-Path $PSScriptRoot $name))
        try { $encoder.Save($stream) } finally { $stream.Dispose() }
    }
}
Render-Notifications
