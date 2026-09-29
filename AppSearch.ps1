# Local app launcher. App indexing runs off the WPF UI thread.
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class AppSearchNative {
 [DllImport("user32.dll",SetLastError=true)] public static extern bool RegisterHotKey(IntPtr h,int id,uint modifiers,uint key);
 [DllImport("user32.dll")] public static extern bool UnregisterHotKey(IntPtr h,int id);
}
'@
$script:appSearchHotkeyId = 0x5143
$script:appSearchApps = @()
$script:appSearchIndexedAt = [DateTime]::MinValue
$script:appSearchClosing = $false
$script:appSearchIndexError = $false
[xml]$appSearchXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 Title="Search apps" Width="620" SizeToContent="Height" WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True" Background="Transparent" ShowInTaskbar="False" Topmost="True" FontFamily="Segoe UI" Foreground="White" UseLayoutRounding="True">
 <Border CornerRadius="22" BorderThickness="1" Padding="20">
  <Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,1"><GradientStop Color="#FF414D5E" Offset="0"/><GradientStop Color="#FF202A39" Offset="0.65"/><GradientStop Color="#FF303B4B" Offset="1"/></LinearGradientBrush></Border.Background>
  <Border.BorderBrush><LinearGradientBrush StartPoint="0,0" EndPoint="1,1"><GradientStop Color="#BBDDEAFF" Offset="0"/><GradientStop Color="#335B7493" Offset="0.5"/><GradientStop Color="#778FA9C9" Offset="1"/></LinearGradientBrush></Border.BorderBrush>
  <StackPanel>
   <Grid Margin="2,0,2,14"><Grid.ColumnDefinitions><ColumnDefinition Width="32"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
    <TextBlock Text="&#xE721;" FontFamily="Segoe MDL2 Assets" FontSize="20" VerticalAlignment="Center" Foreground="#C2D7F1"/>
    <TextBox x:Name="AppQuery" Grid.Column="1" FontSize="23" Foreground="White" Background="Transparent" BorderThickness="0" CaretBrush="White" Padding="4,8" AutomationProperties.Name="Search installed apps"/>
    <TextBlock x:Name="AppPlaceholder" Grid.Column="1" Text="Search apps" FontSize="23" Foreground="#A8B7CA" Margin="5,8,0,0" IsHitTestVisible="False"/>
    <TextBlock Grid.Column="2" Text="ESC" FontSize="10" Foreground="#A8B7CA" VerticalAlignment="Center" Margin="10,0,0,0"/>
   </Grid>
   <Border Height="1" Background="#25FFFFFF"/>
   <ListBox x:Name="AppResults" Background="Transparent" BorderThickness="0" Foreground="White" Margin="0,10,0,8" MaxHeight="352" ScrollViewer.HorizontalScrollBarVisibility="Disabled" ScrollViewer.VerticalScrollBarVisibility="Auto" AutomationProperties.Name="Matching apps">
    <ListBox.ItemContainerStyle><Style TargetType="ListBoxItem"><Setter Property="HorizontalContentAlignment" Value="Stretch"/><Setter Property="Padding" Value="12,9"/><Setter Property="Margin" Value="0,2"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ListBoxItem"><Border x:Name="Row" Background="Transparent" CornerRadius="10" Padding="{TemplateBinding Padding}"><ContentPresenter/></Border><ControlTemplate.Triggers><Trigger Property="IsSelected" Value="True"><Setter TargetName="Row" Property="Background" Value="#446F9FE2"/></Trigger><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Row" Property="Background" Value="#287FA5DA"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style></ListBox.ItemContainerStyle>
    <ListBox.ItemTemplate><DataTemplate><DockPanel><TextBlock DockPanel.Dock="Right" Text="{Binding Kind}" Foreground="#A8B7CA" FontSize="10" VerticalAlignment="Center" Margin="16,0,0,0"/><TextBlock Text="{Binding Name}" FontSize="14" TextTrimming="CharacterEllipsis"/></DockPanel></DataTemplate></ListBox.ItemTemplate>
   </ListBox>
   <TextBlock x:Name="AppSearchStatus" Text="Type an app name   ·   ↑ ↓ select   ·   Enter open" Foreground="#ACBED3" FontSize="11" Margin="5,4,0,0"/>
  </StackPanel>
 </Border>
</Window>
'@
$script:appSearchWindow = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($appSearchXaml))
$script:appSearchQuery = $appSearchWindow.FindName('AppQuery')
$script:appSearchResults = $appSearchWindow.FindName('AppResults')
$script:appSearchStatus = $appSearchWindow.FindName('AppSearchStatus')

function Find-LauncherApps($Apps,[string]$Query) {
    $terms = @($Query.Trim().Split(' ') | Where-Object { $_ })
    $matches = foreach ($app in $Apps) {
        $include = $true
        foreach ($term in $terms) { if ($app.Name.IndexOf($term,[StringComparison]::OrdinalIgnoreCase) -lt 0) { $include = $false; break } }
        if ($include) { $app }
    }
    @($matches | Sort-Object @{Expression={ if ($Query -and $_.Name.Equals($Query,[StringComparison]::OrdinalIgnoreCase)) {0} elseif ($Query -and $_.Name.StartsWith($Query,[StringComparison]::OrdinalIgnoreCase)) {1} else {2} }},Name | Select-Object -First 12)
}
function Update-AppSearchResults {
    $query = $script:appSearchQuery.Text
    $script:appSearchWindow.FindName('AppPlaceholder').Visibility = if ($query) { 'Collapsed' } else { 'Visible' }
    $script:appSearchResults.ItemsSource = @(Find-LauncherApps $script:appSearchApps $query)
    if ($script:appSearchResults.Items.Count) { $script:appSearchResults.SelectedIndex = 0 }
    $script:appSearchStatus.Text = if ($script:appSearchIndexJob) { 'Indexing installed apps...' } elseif ($script:appSearchIndexError) { 'App indexing failed. Close and reopen to retry.' } elseif (-not $script:appSearchResults.Items.Count) { 'No matching apps. Try a different name.' } else { 'Ctrl+Shift+Q   ·   ↑ ↓ select   ·   Enter open' }
    if ($script:appSearchHotkeyFailed) { $script:appSearchStatus.Text += '   |   Hotkey in use by another app' }
}
function Start-AppSearchIndex {
    if ($script:appSearchIndexJob -or ([DateTime]::Now - $script:appSearchIndexedAt).TotalMinutes -lt 5) { return }
    $script:appSearchIndexError = $false
    $script:appSearchIndexWorker = [PowerShell]::Create()
    [void]$script:appSearchIndexWorker.AddScript({
        $seen = @{}
        foreach ($folder in @([Environment]::GetFolderPath('Programs'),[Environment]::GetFolderPath('CommonPrograms'),[Environment]::GetFolderPath('Desktop'),[Environment]::GetFolderPath('CommonDesktopDirectory'))) {
            if (-not $folder) { continue }
            Get-ChildItem -LiteralPath $folder -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.lnk','.appref-ms') } | ForEach-Object {
                if (-not $seen.ContainsKey($_.BaseName)) { $seen[$_.BaseName]=$true; [pscustomobject]@{Name=$_.BaseName;Target=$_.FullName;Kind='Shortcut'} }
            }
        }
        if (Get-Command Get-StartApps -ErrorAction SilentlyContinue) {
            Get-StartApps -ErrorAction SilentlyContinue | ForEach-Object {
                if (-not $seen.ContainsKey($_.Name)) { $seen[$_.Name]=$true; [pscustomobject]@{Name=$_.Name;Target=$_.AppID;Kind='App'} }
            }
        }
    }.ToString())
    $script:appSearchIndexJob = $script:appSearchIndexWorker.BeginInvoke()
    $script:appSearchIndexStarted = [DateTime]::Now
}
function Open-LauncherSelection {
    $item = $script:appSearchResults.SelectedItem
    if (-not $item) { return }
    try {
        $start = [Diagnostics.ProcessStartInfo]::new(); $start.UseShellExecute=$true
        if ($item.Kind -eq 'App') { $start.FileName='explorer.exe'; $start.Arguments='shell:AppsFolder\' + [string]$item.Target }
        else { $start.FileName=[string]$item.Target }
        [void][Diagnostics.Process]::Start($start)
        $script:appSearchWindow.Hide()
    } catch { $script:appSearchStatus.Text='This app could not be opened. Its shortcut may have moved.' }
}
function Show-AppSearch {
    if ($script:appSearchWindow.IsVisible) { $script:appSearchWindow.Hide(); return }
    Start-AppSearchIndex
    $work = [Windows.SystemParameters]::WorkArea
    $script:appSearchWindow.Width = [Math]::Min(620,$work.Width-32)
    $script:appSearchWindow.Left = $work.Left + ($work.Width-$script:appSearchWindow.Width)/2
    $script:appSearchQuery.Text=''; Update-AppSearchResults
    $script:appSearchWindow.Show(); $script:appSearchWindow.UpdateLayout()
    $script:appSearchWindow.Top = $work.Top + [Math]::Max(16,($work.Height-$script:appSearchWindow.ActualHeight)/2)
    [void]$script:appSearchWindow.Activate(); [void]$script:appSearchQuery.Focus()
}
$appSearchQuery.Add_TextChanged({ Update-AppSearchResults })
$appSearchWindow.Add_PreviewKeyDown({
    param($sender,$e)
    if ($e.Key -eq 'Escape') { $sender.Hide(); $e.Handled=$true }
    elseif ($e.Key -eq 'Enter') { Open-LauncherSelection; $e.Handled=$true }
    elseif ($e.Key -in @('Down','Up') -and $script:appSearchResults.Items.Count) {
        $step=if($e.Key -eq 'Down'){1}else{-1}
        $script:appSearchResults.SelectedIndex=[Math]::Max(0,[Math]::Min($script:appSearchResults.Items.Count-1,$script:appSearchResults.SelectedIndex+$step))
        $script:appSearchResults.ScrollIntoView($script:appSearchResults.SelectedItem); $e.Handled=$true
    }
})
$appSearchResults.Add_MouseDoubleClick({ Open-LauncherSelection })
$appSearchWindow.Add_SizeChanged({
    if ($script:appSearchWindow.IsVisible) {
        $work=[Windows.SystemParameters]::WorkArea
        $script:appSearchWindow.Top=$work.Top+[Math]::Max(16,($work.Height-$script:appSearchWindow.ActualHeight)/2)
        $script:appSearchResults.MaxHeight=[Math]::Min(352,[Math]::Max(80,$work.Height-180))
    }
})
$appSearchWindow.Add_Closing({ param($sender,$e) if (-not $script:appSearchClosing) { $e.Cancel=$true; $sender.Hide() } })
$appSearchWindow.Add_Deactivated({ if (-not $script:appSearchClosing) { $script:appSearchWindow.Hide() } })
$script:appSearchIndexTimer = [Windows.Threading.DispatcherTimer]::new(); $appSearchIndexTimer.Interval=[TimeSpan]::FromMilliseconds(150)
$appSearchIndexTimer.Add_Tick({
    if (-not $script:appSearchIndexJob) { return }
    if ($script:appSearchIndexJob.IsCompleted) {
        try { $script:appSearchApps=@($script:appSearchIndexWorker.EndInvoke($script:appSearchIndexJob)); $script:appSearchIndexedAt=[DateTime]::Now }
        catch { $script:appSearchIndexError=$true }
        finally { $script:appSearchIndexWorker.Dispose(); $script:appSearchIndexWorker=$null; $script:appSearchIndexJob=$null }
        Update-AppSearchResults
    } elseif (([DateTime]::Now-$script:appSearchIndexStarted).TotalSeconds -gt 30) {
        $script:appSearchIndexWorker.Stop(); $script:appSearchIndexWorker.Dispose(); $script:appSearchIndexWorker=$null; $script:appSearchIndexJob=$null; $script:appSearchIndexError=$true
        Update-AppSearchResults
    }
})
function Start-AppSearchHotkey {
    $script:appSearchHwndSource = [Windows.Interop.HwndSource]::FromHwnd($script:hwnd)
    $script:appSearchHook = [Windows.Interop.HwndSourceHook]{
        param([IntPtr]$h,[int]$message,[IntPtr]$w,[IntPtr]$l,[ref]$handled)
        if ($message -eq 0x312 -and $w.ToInt32() -eq $script:appSearchHotkeyId) { Show-AppSearch; $handled.Value=$true }
        return [IntPtr]::Zero
    }
    $script:appSearchHwndSource.AddHook($script:appSearchHook)
    $script:appSearchHotkeyFailed = -not [AppSearchNative]::RegisterHotKey($script:hwnd,$script:appSearchHotkeyId,0x4006,0x51)
    $script:appSearchIndexTimer.Start()
}
function Stop-AppSearch {
    $script:appSearchClosing=$true
    if ($script:appSearchIndexTimer) { $script:appSearchIndexTimer.Stop() }
    if ($script:appSearchHwndSource) { [void][AppSearchNative]::UnregisterHotKey($script:hwnd,$script:appSearchHotkeyId); $script:appSearchHwndSource.RemoveHook($script:appSearchHook) }
    if ($script:appSearchIndexWorker) { $script:appSearchIndexWorker.Stop(); $script:appSearchIndexWorker.Dispose() }
    if ($script:appSearchWindow) { $script:appSearchWindow.Close() }
}
