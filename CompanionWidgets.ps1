# Local companion: no cloud model, microphone, or application history.
Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class CompanionNative {
    [StructLayout(LayoutKind.Sequential)] struct INPUT { public uint size, time; }
    [DllImport("user32.dll")] static extern bool GetLastInputInfo(ref INPUT info);
    [DllImport("user32.dll")] static extern IntPtr OpenInputDesktop(uint flags, bool inherit, uint access);
    [DllImport("user32.dll")] static extern bool CloseDesktop(IntPtr desktop);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern bool GetUserObjectInformation(IntPtr h, int index, StringBuilder value, int size, out int needed);
    [DllImport("shell32.dll")] static extern int SHQueryUserNotificationState(out int state);
    public static double IdleSeconds() {
        var info = new INPUT(); info.size = (uint)Marshal.SizeOf(info);
        if (!GetLastInputInfo(ref info)) return Double.PositiveInfinity;
        return unchecked((uint)Environment.TickCount - info.time) / 1000.0;
    }
    public static bool Unlocked() {
        IntPtr h = OpenInputDesktop(0, false, 1);
        if (h == IntPtr.Zero) return false;
        try { var name = new StringBuilder(256); int needed;
            return GetUserObjectInformation(h, 2, name, 512, out needed) && name.ToString() == "Default";
        } finally { CloseDesktop(h); }
    }
    public static bool CanNotify() {
        int state; return SHQueryUserNotificationState(out state) == 0 && state == 5;
    }
}
'@

. (Join-Path $PSScriptRoot 'PetPlayground.ps1')

[xml]$dayMarkup = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Daylight window" Width="256" Height="216" WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True" Background="Transparent" ShowInTaskbar="False" ShowActivated="False" Opacity="0" FontFamily="Segoe UI" Foreground="White">
 <Grid Margin="4"><Grid.RenderTransform><TranslateTransform x:Name="DaylightSlide"/></Grid.RenderTransform>
  <Border x:Name="DaylightGlass" CornerRadius="20" BorderThickness="1"/>
  <StackPanel Margin="14,12">
   <Grid><TextBlock Text="DAYLIGHT WINDOW" FontSize="10" FontWeight="SemiBold" Foreground="#CAE6ED"/><TextBlock Text="BANGKOK" HorizontalAlignment="Right" FontSize="9" Foreground="#BBD0EB"/></Grid>
   <Border Margin="0,10,0,8" CornerRadius="12" ClipToBounds="True" Height="118">
    <Canvas x:Name="Sky" Width="220" Height="118" ClipToBounds="True">
     <Rectangle x:Name="SkyColor" Width="220" Height="118"/>
     <Canvas x:Name="Stars"><Ellipse Canvas.Left="25" Canvas.Top="22" Width="2" Height="2" Fill="White"/><Ellipse Canvas.Left="82" Canvas.Top="13" Width="3" Height="3" Fill="White"/><Ellipse Canvas.Left="165" Canvas.Top="25" Width="2" Height="2" Fill="White"/><Ellipse Canvas.Left="194" Canvas.Top="11" Width="2" Height="2" Fill="White"/><Ellipse Canvas.Left="112" Canvas.Top="34" Width="2" Height="2" Fill="White"/></Canvas>
     <Ellipse x:Name="SunGlow" Width="44" Height="44" Fill="#28FFE8A7"/>
     <Ellipse x:Name="Sun" Width="22" Height="22" Fill="#FFE8A7"/>
     <Path x:Name="FarHills" Data="M 0,89 Q 32,53 65,83 Q 119,38 170,82 Q 195,58 220,75 L 220,118 0,118 Z" Fill="#527D90"/>
     <Path x:Name="NearHills" Data="M 0,100 Q 58,64 118,102 Q 166,75 220,94 L 220,118 0,118 Z" Fill="#274957"/>
     <Path Data="M 29,112 V 77 M 17,91 L 29,72 41,91 M 19,101 L 29,83 39,101 M 194,116 V 91 M 185,104 L 194,87 203,104" Stroke="#193847" StrokeThickness="3" Fill="#193847"/>
    </Canvas>
   </Border>
   <TextBlock x:Name="DaylightPhase" FontSize="15" FontWeight="SemiBold"/>
   <TextBlock x:Name="DaylightDetail" FontSize="10" Margin="0,3,0,0" Foreground="#C2D6E6"/>
  </StackPanel>
 </Grid>
</Window>
'@
$script:daylightWindow = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($dayMarkup))
$script:cornerCards += @{ Name='Daylight'; Window=$daylightWindow; Slide=$daylightWindow.FindName('DaylightSlide'); Handle=[IntPtr]::Zero; Visible=$false; LastNear=[DateTime]::MinValue; Offset=10; Anchor='BottomLeft' }

[xml]$petMarkup = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Codex desktop pet" Width="240" Height="244" WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True" Background="Transparent" ShowInTaskbar="False" ShowActivated="False" Opacity="0" FontFamily="Segoe UI" Foreground="White">
 <Grid Margin="4"><Grid.RenderTransform><TranslateTransform x:Name="PetSlide"/></Grid.RenderTransform>
  <Border x:Name="PetGlass" Visibility="Collapsed"/>
  <StackPanel>
   <Border BorderBrush="#658AB6EE" BorderThickness="1" CornerRadius="14" Padding="12,7">
    <Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,1"><GradientStop Color="#F02B3D5F" Offset="0"/><GradientStop Color="#F017233B" Offset="1"/></LinearGradientBrush></Border.Background>
    <StackPanel><DockPanel><TextBlock Text="CODEX BUDDY" FontSize="9" Foreground="#B8D5FF" FontWeight="SemiBold"/><TextBlock x:Name="PetMood" Text="CURIOUS" HorizontalAlignment="Right" FontSize="8" Foreground="#B3E9DA"/></DockPanel><TextBlock x:Name="PetCaption" Text="A tiny friend for your corner of the world." Height="30" FontSize="11" Margin="0,3,0,0" TextWrapping="Wrap"/></StackPanel>
   </Border>
   <Grid Height="124" Width="220">
    <ContentControl x:Name="PetArt" HorizontalAlignment="Center" Cursor="Hand" ToolTip="Click to give a head pat. Right-click for games, treats and outfits. Ctrl+drag to move."/>
    <Canvas x:Name="PetBubbles" Background="Transparent" Visibility="Collapsed"/>
   </Grid>
   <TextBlock x:Name="PetBond" Text="LEVEL 1 / NEW FRIENDS" HorizontalAlignment="Center" FontSize="9" Foreground="#B3E9DA"/>
   <TextBlock x:Name="PetToday" Text="Active today: 0m" HorizontalAlignment="Center" FontSize="10" Foreground="#D9E8FF"/>
   <UniformGrid Columns="3" Margin="12,4,12,0">
    <Button x:Name="PetPatButton" Content="Pat" ToolTip="Give your buddy a head pat"/>
    <Button x:Name="PetTreatButton" Content="Treat" ToolTip="Share a star cookie"/>
    <Button x:Name="PetPlayButton" Content="More +" ToolTip="Open the buddy's activities and wardrobe"/>
   </UniformGrid>
  </StackPanel>
 </Grid>
</Window>
'@
$script:petWindow = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($petMarkup))
$script:petArt = New-VectorPet
$petWindow.FindName('PetArt').Content = $petArt
$script:petBob = $petArt.FindName('BuddyFloat')
$script:cornerCards += @{ Name='Pet'; Window=$petWindow; Slide=$petWindow.FindName('PetSlide'); Handle=[IntPtr]::Zero; Visible=$false; LastNear=[DateTime]::MinValue; Offset=280; Anchor='BottomLeft' }

[xml]$toastMarkup = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="A little nudge from Codex buddy" Width="370" Height="190" WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True" Background="Transparent" ShowInTaskbar="False" ShowActivated="False" Topmost="True" FontFamily="Segoe UI" Foreground="White">
 <Border Background="#F51B2940" BorderBrush="#888AADEA" BorderThickness="1" CornerRadius="18" Padding="12">
  <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="78"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
   <ContentControl x:Name="ToastPet" VerticalAlignment="Center"/>
   <StackPanel Grid.Column="1" Margin="8,1,0,0">
    <Grid><TextBlock Text="A LITTLE CHECK-IN" Foreground="#9DBFFF" FontSize="10" FontWeight="SemiBold"/><Button x:Name="DismissPet" Content="&#x00D7;" HorizontalAlignment="Right" Background="Transparent" Foreground="White" BorderThickness="0" FontSize="15" ToolTip="Dismiss"/></Grid>
    <TextBlock x:Name="ToastMessage" FontSize="12" LineHeight="18" TextWrapping="Wrap" Margin="0,8,0,9"/>
    <Button x:Name="SnoozePet" Content="Quiet for 2 hours" HorizontalAlignment="Left" Padding="9,4" Background="#304563" Foreground="#E4EDFF" BorderThickness="0"/>
   </StackPanel>
  </Grid>
 </Border>
</Window>
'@
$script:petToast = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($toastMarkup))
$toastArt = New-VectorPet; $toastArt.Width=76; $toastArt.Height=90
$petToast.FindName('ToastPet').Content = $toastArt
$petToast.Add_SourceInitialized({
    $handle = [Windows.Interop.WindowInteropHelper]::new($script:petToast).Handle
    $style = [DesktopHost]::GetWindowLong($handle,-20)
    [void][DesktopHost]::SetWindowLong($handle,-20,($style -bor 0x80 -bor 0x08000000))
})
$petToast.FindName('DismissPet').Add_Click({ $script:petToast.Hide() })
$petToast.FindName('SnoozePet').Add_Click({ Set-PetSnooze })

$script:companionStatePath = Join-Path $PSScriptRoot 'companion-state.json'
$script:companionState = @{ day=[DateTime]::Today.ToString('yyyy-MM-dd'); seconds=0.0; muted=$false; snoozeUntil=''; nextAt=[DateTime]::UtcNow.AddMinutes((Get-Random -Minimum 60 -Maximum 121)).ToString('o'); play=(New-PetProgress) }
if (-not $Preview -and (Test-Path -LiteralPath $companionStatePath)) {
    try {
        $saved = Get-Content -LiteralPath $companionStatePath -Raw | ConvertFrom-Json
        $companionState.play = ConvertTo-PetProgress $saved.play
        if ($saved.day -eq $companionState.day -and $saved.seconds -ge 0 -and $saved.seconds -le 86400) { $companionState.seconds = [double]$saved.seconds }
        if ($saved.muted -is [bool]) { $companionState.muted = $saved.muted }
        foreach ($key in @('snoozeUntil','nextAt')) {
            $parsed = [DateTime]::MinValue
            if ([DateTime]::TryParse([string]$saved.$key, [ref]$parsed)) { $companionState[$key] = $parsed.ToUniversalTime().ToString('o') }
        }
    } catch { }
}
$script:companionWatch = [Diagnostics.Stopwatch]::StartNew()
$script:lastCompanionTick = 0.0
$script:lastCompanionSave = 0.0
$script:toastUntil = [DateTime]::MinValue
$script:lastDaylightMinute = ''
$script:petLastTip = -1
$script:petTips = @('Take a few sips of water.', 'Let your shoulders drop and relax your hands.', 'Look away from the screen for a little while.', 'Stand up and enjoy a short stretch.', 'Take a tiny walk around your room.', 'Rest your eyes and take three slow breaths.', 'Clear one little thing from your desk.', 'Pick one small thing to finish next.')
function Save-CompanionState {
    if ($Preview) { return }
    try {
        $temporary = $script:companionStatePath + '.tmp'
        [IO.File]::WriteAllText($temporary, ($script:companionState | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
        if ([IO.File]::Exists($script:companionStatePath)) { [IO.File]::Replace($temporary,$script:companionStatePath,[System.Management.Automation.Language.NullString]::Value) }
        else { [IO.File]::Move($temporary,$script:companionStatePath) }
        $script:companionSaveFailed = $false
    } catch { $script:companionSaveFailed = $true }
}
function Get-ActiveTimeLabel([double]$Seconds) {
    $minutes = [int][Math]::Floor($Seconds / 60)
    if ($minutes -lt 60) { return "${minutes}m" }
    return ('{0}h {1:00}m' -f [int][Math]::Floor($minutes / 60), ($minutes % 60))
}
function Add-CompanionActivity([DateTime]$Now, [double]$Elapsed, [double]$Idle, [bool]$Unlocked) {
    $validInterval = $Elapsed -gt 0 -and $Elapsed -le 15
    $day = $Now.ToString('yyyy-MM-dd')
    if ($script:companionState.day -ne $day) { $script:companionState.day=$day; $script:companionState.seconds=0.0; $Elapsed=[Math]::Min($Elapsed,$Now.TimeOfDay.TotalSeconds) }
    if ($Unlocked -and $Idle -lt 60 -and $validInterval) {
        $script:companionState.seconds = [Math]::Min(86400.0,$script:companionState.seconds+$Elapsed)
    }
}
function Set-PetSnooze {
    $script:companionState.snoozeUntil = [DateTime]::UtcNow.AddHours(2).ToString('o')
    $script:petToast.Hide()
    $script:petWindow.FindName('PetCaption').Text = 'Taking a quiet little break for 2 hours.'
    Save-CompanionState
}
function Show-PetNudge {
    $choices = @(0..($script:petTips.Count-1) | Where-Object { $_ -ne $script:petLastTip })
    $script:petLastTip = Get-Random -InputObject $choices
    $message = "It's $([DateTime]::Now.ToString('HH:mm')). About $(Get-ActiveTimeLabel $script:companionState.seconds) active today.`n$($script:petTips[$script:petLastTip])"
    $script:petWindow.FindName('PetCaption').Text = $script:petTips[$script:petLastTip]
    $script:petToast.FindName('ToastMessage').Text = $message
    $work = [Windows.SystemParameters]::WorkArea
    $script:petToast.Left = $work.Right - $script:petToast.Width - 16
    $script:petToast.Top = $work.Bottom - $script:petToast.Height - 16
    $script:petToast.Show()
    $script:toastUntil = [DateTime]::UtcNow.AddSeconds(22)
}
$petWindow.FindName('PetArt').Add_MouseLeftButtonUp({ Invoke-PetAction 'Pat' })
$petWindow.ContextMenu = [Windows.Controls.ContextMenu]::new()
$petNow = [Windows.Controls.MenuItem]::new(); $petNow.Header='Tell me the time + a little nudge'; $petNow.Add_Click({ Show-PetNudge })
$petQuiet = [Windows.Controls.MenuItem]::new(); $petQuiet.Header='Quiet for 2 hours'; $petQuiet.Add_Click({ Set-PetSnooze })
$script:petMute = [Windows.Controls.MenuItem]::new(); $petMute.Header='Mute automatic reminders'; $petMute.IsCheckable=$true; $petMute.IsChecked=$companionState.muted
$petMute.Add_Click({
    $script:companionState.muted=[bool]$script:petMute.IsChecked
    $script:petToast.Hide()
    $script:companionState.nextAt=[DateTime]::UtcNow.AddMinutes((Get-Random -Minimum 60 -Maximum 121)).ToString('o')
    Save-CompanionState
})
foreach ($item in @($petNow,$petQuiet,$petMute)) { [void]$petWindow.ContextMenu.Items.Add($item) }
Initialize-PetPlayground

function Get-DaylightState([DateTime]$Now, $Data) {
    $rise=$Now.Date.AddHours(6); $set=$Now.Date.AddHours(18); $nextRise=$rise.AddDays(1); $estimated=$true
    $nextKnown=$false
    if ($Data.daily) {
        for ($i=0; $i -lt @($Data.daily.time).Count; $i++) {
            if ($Data.daily.time[$i] -eq $Now.ToString('yyyy-MM-dd')) {
                try {
                    $candidateRise=[DateTime]::Parse($Data.daily.sunrise[$i]); $candidateSet=[DateTime]::Parse($Data.daily.sunset[$i])
                    if ($candidateRise.Date -eq $Now.Date -and $candidateSet -gt $candidateRise) { $rise=$candidateRise; $set=$candidateSet; $estimated=$false }
                    if ($i+1 -lt @($Data.daily.time).Count) { $nextRise=[DateTime]::Parse($Data.daily.sunrise[$i+1]); $nextKnown=$true }
                } catch { }
            }
        }
    }
    $day = $Now -ge $rise -and $Now -lt $set
    $phase = if (-not $day) { 'Under the stars' } elseif (($Now-$rise).TotalMinutes -lt 60) { 'A new day begins' } elseif (($set-$Now).TotalMinutes -lt 60) { 'Golden hour' } else { 'A little pocket of daylight' }
    $next = if ($Now -lt $rise) { $rise } elseif ($day) { $set } else { $nextRise }
    $event = if ($day) { 'Sunset' } else { 'Sunrise' }
    if ($Now -ge $set -and -not $nextKnown) { $estimated=$true }
    $remaining = Get-ActiveTimeLabel ([Math]::Max(0,($next-$Now).TotalSeconds))
    $detail = if ($estimated) { 'Approximate scene | sunrise data offline' } else { "$event $($next.ToString('HH:mm')) | in $remaining" }
    return @{ Day=$day; Phase=$phase; Detail=$detail; Warm=($day -and (($Now-$rise).TotalMinutes -lt 60 -or ($set-$Now).TotalMinutes -lt 60)); Progress=[Math]::Max(0.0,[Math]::Min(1.0,($Now-$rise).TotalSeconds/($set-$rise).TotalSeconds)); Estimated=$estimated }
}
function Update-Daylight([DateTime]$Now, $Data) {
    $scene = Get-DaylightState $Now $Data
    $script:daylightWindow.FindName('DaylightPhase').Text=$scene.Phase
    $script:daylightWindow.FindName('DaylightDetail').Text=$scene.Detail
    $top = if (-not $scene.Day) { '#111C42' } elseif ($scene.Warm) { '#8C72A4' } else { '#518FC0' }
    $bottom = if (-not $scene.Day) { '#3D506C' } elseif ($scene.Warm) { '#F4BE88' } else { '#BCE7DF' }
    $brush=[Windows.Media.LinearGradientBrush]::new([Windows.Media.ColorConverter]::ConvertFromString($top),[Windows.Media.ColorConverter]::ConvertFromString($bottom),90)
    $daylightWindow.FindName('SkyColor').Fill=$brush
    $daylightWindow.FindName('Stars').Visibility=if ($scene.Day) { 'Collapsed' } else { 'Visible' }
    $sun=$daylightWindow.FindName('Sun'); $glow=$daylightWindow.FindName('SunGlow')
    $sun.Fill=[Windows.Media.BrushConverter]::new().ConvertFromString($(if ($scene.Day) { '#FFE8A7' } else { '#D6EEFA' }))
    $x=if ($scene.Day) { 18+162*$scene.Progress } else { 151 }; $y=if ($scene.Day) { 72-58*[Math]::Sin([Math]::PI*$scene.Progress) } else { 18 }
    [Windows.Controls.Canvas]::SetLeft($sun,$x); [Windows.Controls.Canvas]::SetTop($sun,$y)
    [Windows.Controls.Canvas]::SetLeft($glow,$x-11); [Windows.Controls.Canvas]::SetTop($glow,$y-11)
    $daylightWindow.FindName('FarHills').Fill=[Windows.Media.BrushConverter]::new().ConvertFromString($(if ($scene.Day) { '#527D90' } else { '#34465F' }))
    $daylightWindow.FindName('NearHills').Fill=[Windows.Media.BrushConverter]::new().ConvertFromString($(if ($scene.Day) { '#274F59' } else { '#203244' }))
}
function Test-PetReminderDue($State, [DateTime]$Utc, [bool]$Enabled, [bool]$Unlocked, [double]$Idle, [bool]$CanNotify) {
    if (-not $Enabled -or $State.muted -or -not $Unlocked -or $Idle -ge 60 -or -not $CanNotify) { return $false }
    if ($State.snoozeUntil -and $Utc -lt [DateTime]::Parse($State.snoozeUntil).ToUniversalTime()) { return $false }
    return $Utc -ge [DateTime]::Parse($State.nextAt).ToUniversalTime()
}
function Update-Companions {
    if ($Preview) { return }
    $elapsed=$script:companionWatch.Elapsed.TotalSeconds
    Update-PetPlayground
    if ($elapsed-$script:lastCompanionTick -lt 1) { return }
    $delta=$elapsed-$script:lastCompanionTick; $script:lastCompanionTick=$elapsed
    $now=[DateTime]::Now; $utc=[DateTime]::UtcNow
    $idle=[CompanionNative]::IdleSeconds(); $unlocked=[CompanionNative]::Unlocked()
    Add-CompanionActivity $now $delta $idle $unlocked
    $petWindow.FindName('PetToday').Text='Active today: '+(Get-ActiveTimeLabel $companionState.seconds)
    $petWindow.FindName('PetToday').ToolTip=if ($script:companionSaveFailed) { 'Could not save screen time. Check the widget folder is writable.' } else { 'Estimated activity while widgets run. Pauses after 1 minute without input, on lock, or during sleep. No app names or keystrokes stored.' }
    $enabled=$script:widgetPreferences.widgets.Pet.enabled
    if ($petToast.IsVisible -and ($utc -ge $script:toastUntil -or -not $unlocked -or -not $enabled)) { $petToast.Hide() }
    if ($script:petPlay.mode -eq 'Idle' -and (Test-PetReminderDue $companionState $utc $enabled $unlocked $idle ([CompanionNative]::CanNotify()))) {
        Show-PetNudge
        $companionState.nextAt=$utc.AddMinutes((Get-Random -Minimum 60 -Maximum 121)).ToString('o')
        Save-CompanionState
    }
    $bangkok=[TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::UtcNow,'SE Asia Standard Time')
    $minute=$bangkok.ToString('yyyy-MM-dd HH:mm')
    if ($minute -ne $script:lastDaylightMinute) { Update-Daylight $bangkok $script:weatherData; $script:lastDaylightMinute=$minute }
    if ($elapsed-$script:lastCompanionSave -ge 60) { Save-CompanionState; $script:lastCompanionSave=$elapsed }
}
Update-Daylight ([TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::UtcNow,'SE Asia Standard Time')) $null

