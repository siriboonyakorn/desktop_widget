# Desktop menu bar. Uses the suite's visibility, theme and shutdown lifecycle.
[xml]$topBarXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 Title="Desktop menu bar" Width="1280" Height="30" WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True"
 Background="Transparent" ShowInTaskbar="False" ShowActivated="False" Opacity="0" FontFamily="Segoe UI" FontSize="12" Foreground="White">
 <Window.Resources>
  <Style TargetType="Button">
   <Setter Property="Foreground" Value="White"/><Setter Property="Background" Value="Transparent"/><Setter Property="Padding" Value="9,0"/><Setter Property="Cursor" Value="Hand"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
    <Border x:Name="Surface" Background="{TemplateBinding Background}" CornerRadius="5" Padding="{TemplateBinding Padding}"><ContentPresenter VerticalAlignment="Center" HorizontalAlignment="Center"/></Border>
    <ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Surface" Property="Background" Value="#30FFFFFF"/></Trigger><Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Surface" Property="Background" Value="#40FFFFFF"/></Trigger></ControlTemplate.Triggers>
   </ControlTemplate></Setter.Value></Setter>
  </Style>
 </Window.Resources>
 <Grid>
  <Grid.RenderTransform><TranslateTransform x:Name="TopBarSlide" Y="-12"/></Grid.RenderTransform>
  <Border x:Name="TopBarGlass" BorderThickness="0,0,0,1" Padding="12,2">
   <DockPanel LastChildFill="True">
    <StackPanel DockPanel.Dock="Left" Orientation="Horizontal">
     <Button x:Name="DesktopMenu" ToolTip="Windows menu" AutomationProperties.Name="Windows menu"><Path Fill="White" Width="15" Height="15" Stretch="Uniform" Data="M0,0 H7 V7 H0 Z M9,0 H16 V7 H9 Z M0,9 H7 V16 H0 Z M9,9 H16 V16 H9 Z"/></Button>
     <Button x:Name="FinderMenu" Content="Explorer" FontWeight="SemiBold"/>
     <Button x:Name="FileMenu" Content="File"/>
     <Button x:Name="ViewMenu" Content="View"/>
     <Button x:Name="GoMenu" Content="Go"/>
     <Button x:Name="WidgetsMenu" Content="Window"/>
     <Button x:Name="HelpMenu" Content="Help"/>
    </StackPanel>
    <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
     <Button x:Name="BluetoothStatus" Content="&#xE702;" FontFamily="Segoe MDL2 Assets" ToolTip="Bluetooth"/>
     <Button x:Name="NetworkStatus" Content="&#xE701;" FontFamily="Segoe MDL2 Assets" ToolTip="Wi-Fi"/>
     <Button x:Name="SoundSettings" Content="&#xE767;" FontFamily="Segoe MDL2 Assets" ToolTip="Sound"/>
     <Button x:Name="TopBattery" Content="Power" ToolTip="Battery and power settings"/>
     <Button x:Name="SearchMenu" Content="&#xE721;" FontFamily="Segoe MDL2 Assets" ToolTip="Search"/>
     <Button x:Name="BarSettings" ToolTip="Control Center"><Canvas Width="20" Height="18"><Border Width="19" Height="7" CornerRadius="3.5" Background="White" Canvas.Top="0"/><Ellipse Width="5" Height="5" Fill="#454B55" Canvas.Left="2" Canvas.Top="1"/><Border Width="19" Height="7" CornerRadius="3.5" Background="White" Canvas.Top="10"/><Ellipse Width="5" Height="5" Fill="#454B55" Canvas.Left="12" Canvas.Top="11"/></Canvas></Button>
     <Button x:Name="TopClock" Content="Mon 28 Sep   12:00" ToolTip="Date and time settings"/>
    </StackPanel>
    <Border/>
   </DockPanel>
  </Border>
 </Grid>
</Window>
'@
$script:topBarWindow = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($topBarXaml))
$script:topBarWindow.Width = [Windows.SystemParameters]::WorkArea.Width
$script:topBarEntry = @{ Name = 'TopBar'; Window = $topBarWindow; Slide = $topBarWindow.FindName('TopBarSlide'); Handle = [IntPtr]::Zero; Visible = $false; LastNear = [DateTime]::MinValue; Offset = 0; Anchor = 'TopBar'; Configuring = $false }
$script:topBarEntry.Overlay = $true
$script:cornerCards += $topBarEntry

function Add-TopBarMenu([string]$ButtonName, $Items) {
    $button = $topBarWindow.FindName($ButtonName)
    $menu = [Windows.Controls.ContextMenu]::new()
    foreach ($definition in $Items) {
        $item = [Windows.Controls.MenuItem]::new()
        $item.Header = $definition[0]; $item.Tag = $definition[1]
        $item.Add_Click({
            param($sender,$e)
            try {
                if ($sender.Tag -eq 'customize') { Show-WidgetSettings }
                else { Start-Process -FilePath explorer.exe -ArgumentList ([string]$sender.Tag) }
            } catch { [void][Windows.MessageBox]::Show('This location could not be opened.', 'Desktop menu') }
        })
        [void]$menu.Items.Add($item)
    }
    $menu.Add_Opened({ $script:topBarEntry.Configuring = $true })
    $menu.Add_Closed({ $script:topBarEntry.Configuring = $false; $script:topBarEntry.LastNear = [DateTime]::Now })
    $button.ContextMenu = $menu
    $button.Add_Click({
        param($sender,$e)
        $sender.ContextMenu.Resources.MergedDictionaries.Clear()
        $sender.ContextMenu.Resources.MergedDictionaries.Add($script:widgetResources)
        $sender.ContextMenu.PlacementTarget = $sender
        $sender.ContextMenu.Placement = 'Bottom'; $sender.ContextMenu.IsOpen = $true
    })
}
Add-TopBarMenu 'DesktopMenu' @(@('Customize desktop...', 'customize'), @('Windows settings', 'ms-settings:'), @('About this PC', 'ms-settings:about'))
Add-TopBarMenu 'FinderMenu' @(@('Open File Explorer', 'shell:MyComputerFolder'), @('Home folder', 'shell:Profile'), @('Recycle bin', 'shell:RecycleBinFolder'))
Add-TopBarMenu 'FileMenu' @(@('New Explorer window', 'shell:MyComputerFolder'), @('Home', 'shell:Profile'))
Add-TopBarMenu 'ViewMenu' @(@('Desktop settings...', 'ms-settings:personalization'), @('Display settings...', 'ms-settings:display'))
Add-TopBarMenu 'GoMenu' @(@('Desktop', 'shell:Desktop'), @('Documents', 'shell:Personal'), @('Downloads', 'shell:Downloads'), @('Pictures', 'shell:My Pictures'))
Add-TopBarMenu 'WidgetsMenu' @(@('Widgets and layout...', 'customize'))
Add-TopBarMenu 'HelpMenu' @(@('About this desktop', 'ms-settings:about'), @('Customize menu bar...', 'customize'))
. (Join-Path $PSScriptRoot 'TopBarPanels.ps1')
$script:topBarNextRefresh = [DateTime]::MinValue
function Update-TopMenuBar {
    if ([DateTime]::Now -lt $script:topBarNextRefresh) { return }
    $script:topBarNextRefresh = [DateTime]::Now.AddSeconds(1)
    Update-TopPanelState
    $topBarWindow.FindName('TopClock').Content = [DateTime]::Now.ToString(('ddd d MMM   ' + (Get-WidgetTimeFormat)))
    $power = [Windows.Forms.SystemInformation]::PowerStatus
    $percent = $power.BatteryLifePercent
    $topBarWindow.FindName('TopBattery').Content = if (([int]$power.BatteryChargeStatus -band 128) -ne 0 -or $percent -gt 1 -or $percent -lt 0) { 'AC power' } else { '{0:0}%{1}' -f ($percent * 100), $(if ($power.PowerLineStatus -eq 'Online') { ' +' } else { '' }) }
}
