$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'ClockWidget.ps1') -Preview
try {
    $topBarWindow.Opacity=1; $topBarWindow.Show(); $topBarWindow.UpdateLayout()
    $job=[WidgetTray]::ReadAsync()
    if (-not $job.Wait(8000)) { throw 'Tray provider timed out' }
    Write-Output ('Native tray discovery completed: '+$job.Result.Length+' items')
    $network=[MenuWifi+Item]::new(); $network.Name='Test & <network>'; $network.SsidHex='54657374'; $network.Auth=7; $network.Cipher=4; $network.Secure=$true
    [xml]$profile=[MenuWifi]::ProfileXml($network,'abc<&123456')
    if ($profile.WLANProfile.MSM.security.sharedKey.keyMaterial -ne 'abc<&123456') { throw 'Password XML escaping failed' }
    if ($profile.WLANProfile.name -ne $network.Name) { throw 'SSID XML escaping failed' }
    $network.Auth=6
    $rejected=$false
    try { [void][MenuWifi]::ProfileXml($network,'12345678') } catch { $rejected=$true }
    if (-not $rejected) { throw 'Enterprise network accepted a personal password' }
    $network.Auth=7
    Show-TopPanel 'Wi-Fi' $topBarWindow.FindName('NetworkStatus')
    Show-TopWifiJoin $network
    if (-not $script:topWifiPassword -or -not $script:topWifiConnect) { throw 'Wi-Fi join controls missing' }
    $script:topWifiPassword.Password='short'
    Start-TopWifiJoin
    if ($script:topWifiJob) { throw 'Invalid password submitted' }
    if ($script:topWifiPassword.Password) { throw 'Password retained' }
    $script:topWifiPassword.Password='test123456'
    $script:topPanel.IsOpen=$false
    [Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{},[Windows.Threading.DispatcherPriority]::ApplicationIdle)
    if ($script:topWifiPassword.Password) { throw 'Dismissed panel retained password' }
    # Exercise the actual animation clock as an enlarged icon settles after leaving.
    $image=[Windows.Controls.Image]::new(); $image.RenderTransform=[Windows.Media.ScaleTransform]::new(2,2)
    $button=[Windows.Controls.Button]::new(); $button.Content=$image
    [void]$script:macDynamicPanel.Children.Add($button)
    Set-MacDockHover $button $false
    $frame=[Windows.Threading.DispatcherFrame]::new()
    $timer=[Windows.Threading.DispatcherTimer]::new(); $timer.Interval=[TimeSpan]::FromMilliseconds(1200)
    $timer.Add_Tick({$frame.Continue=$false; $timer.Stop()}); $timer.Start()
    [Windows.Threading.Dispatcher]::PushFrame($frame)
    if ([Math]::Abs($image.RenderTransform.ScaleX-1) -gt 0.01) { throw 'Dock did not settle after mouse leave' }
    if ($script:macMotionTimer.IsEnabled) { throw 'Idle dock animation did not stop' }
    Write-Output 'Tray discovery, Wi-Fi credential validation/clearing and motion convergence passed; no network connection changed.'
} finally { foreach ($entry in $script:cornerCards) { $entry.Window.Close() } }
