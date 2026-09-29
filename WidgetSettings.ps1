function New-WidgetSettingsWindow {
[xml]$settingsXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 Title="Desktop settings" Width="1080" Height="780" MinWidth="940" MinHeight="540" WindowStartupLocation="CenterScreen"
 Background="#10141C" Foreground="#F0F5FC" FontFamily="Segoe UI" FontSize="13" ResizeMode="CanResize" ShowInTaskbar="True">
 <Window.Resources>
  <Style TargetType="Button">
   <Setter Property="Background" Value="#252C3A"/><Setter Property="Foreground" Value="#F0F5FC"/><Setter Property="Padding" Value="16,10"/>
   <Setter Property="BorderThickness" Value="0"/><Setter Property="Cursor" Value="Hand"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
    <Border x:Name="Surface" Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
    <ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Surface" Property="Opacity" Value="0.8"/></Trigger><Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Surface" Property="BorderBrush" Value="#C6B7FF"/><Setter TargetName="Surface" Property="BorderThickness" Value="2"/></Trigger></ControlTemplate.Triggers>
   </ControlTemplate></Setter.Value></Setter>
  </Style>
  <Style TargetType="CheckBox">
   <Setter Property="Foreground" Value="#E1EAF6"/><Setter Property="VerticalContentAlignment" Value="Center"/><Setter Property="Margin" Value="0,7,18,7"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="CheckBox">
    <StackPanel Orientation="Horizontal"><Border x:Name="Box" Width="30" Height="17" CornerRadius="9" BorderBrush="#58647A" BorderThickness="1" Background="#202F41"><Ellipse x:Name="Tick" Width="11" Height="11" Fill="#A7B9CE" HorizontalAlignment="Left" Margin="2"/></Border><ContentPresenter Margin="8,0,0,0" VerticalAlignment="Center" RecognizesAccessKey="True"/></StackPanel>
    <ControlTemplate.Triggers><Trigger Property="IsChecked" Value="True"><Setter TargetName="Box" Property="Background" Value="#C6B7FF"/><Setter TargetName="Tick" Property="HorizontalAlignment" Value="Right"/><Setter TargetName="Tick" Property="Fill" Value="#211934"/></Trigger><Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Box" Property="BorderBrush" Value="White"/><Setter TargetName="Box" Property="BorderThickness" Value="2"/></Trigger></ControlTemplate.Triggers>
   </ControlTemplate></Setter.Value></Setter>
  </Style>
  <Style TargetType="ComboBox">
   <Setter Property="Foreground" Value="#E1EAF6"/><Setter Property="MinHeight" Value="34"/><Setter Property="Margin" Value="0,5,0,14"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ComboBox">
    <Grid>
     <ToggleButton Focusable="False" IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}">
      <ToggleButton.Template><ControlTemplate TargetType="ToggleButton"><Border Background="#252C3A" BorderBrush="#394153" BorderThickness="1" CornerRadius="7"><TextBlock Text="&#x2304;" Foreground="#C6B7FF" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,12,0"/></Border></ControlTemplate></ToggleButton.Template>
     </ToggleButton>
     <ContentPresenter Content="{TemplateBinding SelectionBoxItem}" ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}" Margin="11,6,30,6" VerticalAlignment="Center" IsHitTestVisible="False"/>
     <Popup x:Name="PART_Popup" IsOpen="{TemplateBinding IsDropDownOpen}" Placement="Bottom" AllowsTransparency="True" Focusable="False">
      <Border Background="#252C3A" BorderBrush="#58647A" BorderThickness="1" CornerRadius="7" Padding="4" MinWidth="{Binding ActualWidth, RelativeSource={RelativeSource TemplatedParent}}"><ScrollViewer MaxHeight="260"><ItemsPresenter KeyboardNavigation.DirectionalNavigation="Contained"/></ScrollViewer></Border>
     </Popup>
    </Grid>
   </ControlTemplate></Setter.Value></Setter>
  </Style>
  <Style TargetType="ComboBoxItem"><Setter Property="Foreground" Value="#E1EAF6"/><Setter Property="Padding" Value="10,7"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ComboBoxItem"><Border x:Name="Item" Background="Transparent" CornerRadius="5" Padding="{TemplateBinding Padding}"><ContentPresenter/></Border><ControlTemplate.Triggers><Trigger Property="IsHighlighted" Value="True"><Setter TargetName="Item" Property="Background" Value="#405A73"/></Trigger><Trigger Property="IsSelected" Value="True"><Setter TargetName="Item" Property="Background" Value="#334D65"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
  </Style>
  <Style x:Key="SliderTrackButton" TargetType="RepeatButton"><Setter Property="Focusable" Value="False"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="RepeatButton"><Border Background="{TemplateBinding Background}" Height="4" CornerRadius="2"/></ControlTemplate></Setter.Value></Setter></Style>
  <Style TargetType="Slider">
   <Setter Property="VerticalAlignment" Value="Center"/><Setter Property="Minimum" Value="0"/><Setter Property="Maximum" Value="100"/><Setter Property="IsSnapToTickEnabled" Value="True"/><Setter Property="TickFrequency" Value="5"/><Setter Property="Margin" Value="0,7,0,14"/><Setter Property="IsMoveToPointEnabled" Value="True"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Slider"><Grid Height="24" Background="Transparent">
    <Track x:Name="PART_Track">
     <Track.DecreaseRepeatButton><RepeatButton Command="Slider.DecreaseLarge" Style="{StaticResource SliderTrackButton}" Background="#A28DDC"/></Track.DecreaseRepeatButton>
     <Track.IncreaseRepeatButton><RepeatButton Command="Slider.IncreaseLarge" Style="{StaticResource SliderTrackButton}" Background="#394153"/></Track.IncreaseRepeatButton>
     <Track.Thumb><Thumb Width="16" Height="16"><Thumb.Template><ControlTemplate TargetType="Thumb"><Ellipse Fill="#E2D9FF" Stroke="#A28DDC" StrokeThickness="2"/></ControlTemplate></Thumb.Template></Thumb></Track.Thumb>
    </Track>
   </Grid></ControlTemplate></Setter.Value></Setter>
  </Style>
  <Style TargetType="TextBox"><Setter Property="Background" Value="#252C3A"/><Setter Property="Foreground" Value="#F0F5FC"/><Setter Property="BorderBrush" Value="#394153"/><Setter Property="Padding" Value="6,4"/><Setter Property="VerticalContentAlignment" Value="Center"/></Style>
  <Style TargetType="ScrollBar"><Setter Property="Width" Value="10"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ScrollBar">
   <Track x:Name="PART_Track" IsDirectionReversed="True" Orientation="Vertical">
    <Track.DecreaseRepeatButton><RepeatButton Command="ScrollBar.PageUpCommand" Opacity="0" Focusable="False"/></Track.DecreaseRepeatButton>
    <Track.IncreaseRepeatButton><RepeatButton Command="ScrollBar.PageDownCommand" Opacity="0" Focusable="False"/></Track.IncreaseRepeatButton>
    <Track.Thumb><Thumb><Thumb.Template><ControlTemplate TargetType="Thumb"><Border Background="#4C6178" CornerRadius="4" Margin="2"/></ControlTemplate></Thumb.Template></Thumb></Track.Thumb>
   </Track>
  </ControlTemplate></Setter.Value></Setter></Style>
  <Style TargetType="TabControl">
   <Setter Property="Background" Value="Transparent"/><Setter Property="BorderThickness" Value="0"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="TabControl">
    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="180"/><ColumnDefinition Width="24"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
     <Border Background="#171D27" CornerRadius="14" Padding="10,16">
      <DockPanel><StackPanel DockPanel.Dock="Bottom" Margin="10,24,0,8"><TextBlock Text="DESKTOP WIDGETS" FontSize="9" Foreground="#8493A8"/><TextBlock Text="Your personal workspace" FontSize="10" Foreground="#8493A8" Margin="0,6,0,0"/></StackPanel><StackPanel IsItemsHost="True" KeyboardNavigation.TabIndex="1"/></DockPanel>
     </Border>
     <ContentPresenter x:Name="PART_SelectedContentHost" Grid.Column="2" ContentSource="SelectedContent"/>
    </Grid>
   </ControlTemplate></Setter.Value></Setter>
  </Style>
  <Style TargetType="TabItem">
   <Setter Property="Foreground" Value="#A7B9CE"/><Setter Property="Padding" Value="12,15"/><Setter Property="Margin" Value="0,0,0,6"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="TabItem">
    <Border x:Name="Tab" Background="#171D27" CornerRadius="8" Padding="{TemplateBinding Padding}"><ContentPresenter ContentSource="Header"/></Border>
    <ControlTemplate.Triggers><Trigger Property="IsSelected" Value="True"><Setter TargetName="Tab" Property="Background" Value="#3B3157"/><Setter Property="Foreground" Value="White"/></Trigger><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Tab" Property="Opacity" Value="0.8"/></Trigger></ControlTemplate.Triggers>
   </ControlTemplate></Setter.Value></Setter>
  </Style>
  <Style x:Key="Section" TargetType="Border"><Setter Property="Background" Value="#191F2B"/><Setter Property="CornerRadius" Value="12"/><Setter Property="Padding" Value="20"/><Setter Property="Margin" Value="0,0,0,12"/></Style>
  <Style x:Key="Heading" TargetType="TextBlock"><Setter Property="FontSize" Value="16"/><Setter Property="FontWeight" Value="SemiBold"/><Setter Property="Margin" Value="0,0,0,14"/></Style>
 </Window.Resources>
 <Grid Margin="26">
  <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
  <StackPanel Margin="0,0,0,22">
   <TextBlock Text="PERSONALIZATION" Foreground="#B5A3FF" FontSize="10" FontWeight="SemiBold"/>
   <TextBlock Text="Desktop settings" FontSize="30" FontWeight="SemiBold" Margin="0,6,0,6"/>
   <TextBlock Text="A space that feels like yours. Fine-tune the dock, widgets and everyday details." Foreground="#A7B9CE"/>
  </StackPanel>
  <TabControl Grid.Row="1" x:Name="SettingsTabs" SelectedIndex="1">
   <TabItem Header="Appearance">
    <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="0,6,12,0">
     <StackPanel>
      <Border Style="{StaticResource Section}"><StackPanel>
       <TextBlock Text="Colors and surfaces" Style="{StaticResource Heading}"/>
       <Grid><Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="20"/><ColumnDefinition/></Grid.ColumnDefinitions>
        <StackPanel><TextBlock Text="Card finish"/><ComboBox x:Name="Theme"/></StackPanel>
        <StackPanel Grid.Column="2"><TextBlock Text="Accent color"/><ComboBox x:Name="Accent"/></StackPanel>
       </Grid>
       <Border x:Name="ThemeSample" CornerRadius="16" BorderThickness="1" BorderBrush="#80BCE9FF" Padding="20" Margin="0,0,0,16">
        <Grid><StackPanel><TextBlock Text="A CLEARER KIND OF CALM" FontSize="10" Foreground="#D4E5F6"/><TextBlock Text="Your everyday essentials" FontSize="22" FontWeight="Light" Margin="0,6,0,0"/></StackPanel><Ellipse x:Name="AccentSample" Width="16" Height="16" HorizontalAlignment="Right" VerticalAlignment="Top"/></Grid>
       </Border>
       <TextBlock><Run Text="Glass opacity  "/><Run Text="{Binding ElementName=GlassOpacity, Path=Value, StringFormat={}{0:0}%}"/></TextBlock>
       <Slider x:Name="GlassOpacity" Minimum="30" Maximum="100"/>
       <CheckBox x:Name="Motion" Content="Smooth fade and slide animations"/>
       <TextBlock Margin="0,10,0,0"><Run Text="Hide after  "/><Run Text="{Binding ElementName=HideDelay, Path=Value, StringFormat={}{0:0} ms}"/></TextBlock>
       <Slider x:Name="HideDelay" Minimum="100" Maximum="3000" TickFrequency="100"/>
       <TextBlock Text="Pinned cards remain visible while the desktop is active." Foreground="#A7B9CE" FontSize="11"/>
      </StackPanel></Border>
     </StackPanel>
    </ScrollViewer>
   </TabItem>
   <TabItem Header="Widgets &amp; layout">
    <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="0,6,12,0">
     <StackPanel>
      <Border Style="{StaticResource Section}"><StackPanel>
       <TextBlock Text="Widgets and layout" Style="{StaticResource Heading}"/>
       <TextBlock Text="SHOW enables a widget. PIN keeps it visible on the desktop; turn PIN off to reveal it on hover. Click Apply changes to save." TextWrapping="Wrap" Foreground="#A7B9CE" Margin="0,0,0,16"/>
       <Border Background="#252C3A" CornerRadius="8" Padding="12" Margin="0,0,0,16"><StackPanel>
        <TextBlock Text="Dock and menu bar" FontWeight="SemiBold" Margin="0,0,0,5"/>
        <TextBlock Text="Windows Start, File Explorer and your apps fill the bottom dock. Right-click for shortcuts and settings. While using apps, hold the bottom edge for one second to reveal the dock. On the desktop, PIN keeps it visible. The unpinned top bar uses a one-second top-edge hover." TextWrapping="Wrap" Foreground="#B9CBDD"/>
        <TextBlock Margin="0,14,0,0"><Run Text="Dock width  "/><Run Text="{Binding ElementName=DockWidth, Path=Value, StringFormat={}{0:0}% of screen}"/></TextBlock>
        <Slider x:Name="DockWidth" Minimum="50" Maximum="100" TickFrequency="2" Margin="0,8,0,0"/>
        <CheckBox x:Name="HideWindowsTaskbar" Content="Hide Windows taskbar while widgets are running"/>
        <TextBlock Text="Restored automatically when widgets close. Turn this off to bring it back." Foreground="#B9CBDD" FontSize="11"/>
       </StackPanel></Border>
       <Grid Margin="0,0,0,6"><Grid.ColumnDefinitions><ColumnDefinition Width="140"/><ColumnDefinition Width="60"/><ColumnDefinition Width="60"/><ColumnDefinition Width="*"/><ColumnDefinition Width="60"/><ColumnDefinition Width="60"/></Grid.ColumnDefinitions>
        <TextBlock Text="WIDGET" FontSize="10"/><TextBlock Grid.Column="1" Text="SHOW" FontSize="10"/><TextBlock Grid.Column="2" Text="PIN" FontSize="10"/><TextBlock Grid.Column="3" Text="SIZE" FontSize="10"/><TextBlock Grid.Column="4" Text="X OFFSET" FontSize="10"/><TextBlock Grid.Column="5" Text="Y OFFSET" FontSize="10"/>
       </Grid>
       <StackPanel x:Name="WidgetRows"/>
       <Button x:Name="ResetLayout" Content="Reset positions and sizes" HorizontalAlignment="Left" Margin="0,18,0,0"/>
       <TextBlock Text="Hold Ctrl and drag a widget to move it. Positions save automatically. Photo and weather start side by side. X and Y offsets are in display-scaled pixels." TextWrapping="Wrap" Foreground="#A7B9CE" FontSize="11" Margin="0,12,0,0"/>
      </StackPanel></Border>
     </StackPanel>
    </ScrollViewer>
   </TabItem>
   <TabItem Header="Clock &amp; details">
    <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="0,6,12,0">
     <StackPanel>
      <Border Style="{StaticResource Section}"><StackPanel>
       <TextBlock Text="Time, your way" Style="{StaticResource Heading}"/>
       <Grid><Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="20"/><ColumnDefinition/></Grid.ColumnDefinitions>
        <StackPanel><TextBlock Text="Clock style"/><ComboBox x:Name="ClockStyle"/><TextBlock Text="Time format"/><ComboBox x:Name="TimeFormat"/></StackPanel>
        <StackPanel Grid.Column="2"><TextBlock Text="Clock text color"/><ComboBox x:Name="ClockColor"/><TextBlock Text="Date format"/><ComboBox x:Name="DateFormat"/></StackPanel>
       </Grid>
       <TextBlock><Run Text="Clock size  "/><Run Text="{Binding ElementName=ClockScale, Path=Value, StringFormat={}{0:0}%}"/></TextBlock>
       <Slider x:Name="ClockScale" Minimum="65" Maximum="150"/>
       <WrapPanel><CheckBox x:Name="Seconds" Content="Show seconds"/><CheckBox x:Name="Media" Content="Show media controls"/></WrapPanel>
      </StackPanel></Border>
      <Border Style="{StaticResource Section}"><StackPanel>
       <TextBlock Text="Personal touches" Style="{StaticResource Heading}"/>
       <Grid><Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="20"/><ColumnDefinition/></Grid.ColumnDefinitions>
        <StackPanel><TextBlock Text="Photo framing"/><ComboBox x:Name="PhotoFit"/><Button x:Name="ChoosePhoto" Content="Choose a photo..." HorizontalAlignment="Left"/></StackPanel>
        <StackPanel Grid.Column="2"><TextBlock><Run Text="Note text size  "/><Run Text="{Binding ElementName=NoteFont, Path=Value, StringFormat={}{0:0} pt}"/></TextBlock><Slider x:Name="NoteFont" Minimum="10" Maximum="20" TickFrequency="1"/><TextBlock Text="Bangkok weather units"/><ComboBox x:Name="WeatherUnits"/></StackPanel>
       </Grid>
       <TextBlock Text="Right-click the app or folder dock to change its shortcuts. Drag app icons to reorder them." TextWrapping="Wrap" Foreground="#A7B9CE" FontSize="11" Margin="0,18,0,0"/>
      </StackPanel></Border>
     </StackPanel>
    </ScrollViewer>
   </TabItem>
  </TabControl>
  <Grid Grid.Row="2" Margin="0,18,0,0"><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
   <TextBlock x:Name="SettingsStatus" Text="Changes take effect when you click Apply." Foreground="#A7B9CE" VerticalAlignment="Center" TextWrapping="Wrap" Margin="0,0,20,0"/>
   <Button Grid.Column="1" x:Name="CloseSettings" Content="Close" Margin="0,0,10,0"/>
   <Button Grid.Column="2" x:Name="ApplySettings" Content="Apply changes" Background="#C6B7FF" Foreground="#211934" FontWeight="SemiBold"/>
  </Grid>
 </Grid>
</Window>
'@
    $script:settingsWindow = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($settingsXaml))
    $script:settingsRows = @{}
    $choices = @{ Theme = @('Glass','Midnight','Warm'); Accent = @($script:widgetAccents.Keys); ClockStyle = @($styles.Keys); ClockColor = @($colors.Keys); TimeFormat = @('24-hour','12-hour'); PhotoFit = @('Fill','Fit'); WeatherUnits = @('Celsius','Fahrenheit') }
    foreach ($name in $choices.Keys) { foreach ($choice in $choices[$name]) { [void]$script:settingsWindow.FindName($name).Items.Add($choice) } }
    foreach ($format in @('d/M/yyyy','ddd, d MMM','MMMM d, yyyy','yyyy-MM-dd')) {
        $item = [Windows.Controls.ComboBoxItem]::new(); $item.Tag = $format; $item.Content = [DateTime]::Now.ToString($format,[Globalization.CultureInfo]::InvariantCulture)
        [void]$script:settingsWindow.FindName('DateFormat').Items.Add($item)
    }
    foreach ($name in $script:widgetLabels.Keys) {
        $row = [Windows.Controls.Grid]::new(); $row.Margin = [Windows.Thickness]::new(0,7,0,7)
        foreach ($width in @(140,60,60,0,60,60)) {
            $column = [Windows.Controls.ColumnDefinition]::new()
            $column.Width = if ($width -eq 0) { [Windows.GridLength]::new(1,[Windows.GridUnitType]::Star) } else { [Windows.GridLength]::new($width) }
            $row.ColumnDefinitions.Add($column)
        }
        $label = [Windows.Controls.TextBlock]::new(); $label.Text = $script:widgetLabels[$name]; $label.VerticalAlignment = 'Center'
        $enabled = [Windows.Controls.CheckBox]::new(); $enabled.VerticalAlignment = 'Center'; $enabled.ToolTip = 'Show ' + $label.Text + '. Uncheck and Apply to hide completely, even on hover.'
        $pinned = [Windows.Controls.CheckBox]::new(); $pinned.VerticalAlignment = 'Center'; $pinned.ToolTip = if ($name -eq 'TopBar') { 'Keep visible over apps; uncheck to auto-hide' } else { 'Keep visible on desktop' }
        $size = [Windows.Controls.Slider]::new(); $size.Minimum = 70; $size.Maximum = 150; $size.TickFrequency = 5; $size.IsSnapToTickEnabled = $true; $size.AutoToolTipPlacement = 'TopLeft'; $size.AutoToolTipPrecision = 0; $size.Margin = [Windows.Thickness]::new(0,0,14,0)
        $x = [Windows.Controls.TextBox]::new(); $x.Margin = [Windows.Thickness]::new(0,0,5,0)
        $y = [Windows.Controls.TextBox]::new(); $y.Margin = [Windows.Thickness]::new(0,0,5,0)
        if ($name -eq 'TopBar') {
            $x.IsEnabled = $false; $y.IsEnabled = $false
            $x.ToolTip = 'The menu bar stays at the top of the screen.'; $y.ToolTip = $x.ToolTip
            $size.ToolTip = 'Menu bar height'
        }
        $sizePanel = [Windows.Controls.Grid]::new()
        $sizePanel.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]::new())
        $sizeValueColumn = [Windows.Controls.ColumnDefinition]::new(); $sizeValueColumn.Width = [Windows.GridLength]::new(40); $sizePanel.ColumnDefinitions.Add($sizeValueColumn)
        $sizeValue = [Windows.Controls.TextBlock]::new(); $sizeValue.FontSize = 10; $sizeValue.VerticalAlignment = 'Center'
        $binding = [Windows.Data.Binding]::new('Value'); $binding.Source = $size; $binding.StringFormat = '{0:0}%'
        [void]$sizeValue.SetBinding([Windows.Controls.TextBlock]::TextProperty,$binding)
        [Windows.Controls.Grid]::SetColumn($sizeValue,1); [void]$sizePanel.Children.Add($size); [void]$sizePanel.Children.Add($sizeValue)
        $elements = @($label,$enabled,$pinned,$sizePanel,$x,$y)
        for ($i = 0; $i -lt $elements.Count; $i++) { [Windows.Controls.Grid]::SetColumn($elements[$i],$i); [void]$row.Children.Add($elements[$i]) }
        [void]$script:settingsWindow.FindName('WidgetRows').Children.Add($row)
        $script:settingsRows[$name] = @{ enabled = $enabled; pinned = $pinned; scale = $size; x = $x; y = $y }
        foreach ($pair in @(@($enabled,'Show'),@($pinned,'Pin'),@($size,'Size'),@($x,'Horizontal offset'),@($y,'Vertical offset'))) {
            [Windows.Automation.AutomationProperties]::SetName($pair[0], ($label.Text + ' ' + $pair[1]))
        }
    }
    foreach ($name in @('Theme','Accent')) { $script:settingsWindow.FindName($name).Add_SelectionChanged({ Update-SettingsSample }) }
    $script:settingsWindow.FindName('GlassOpacity').Add_ValueChanged({ Update-SettingsSample })
    $script:settingsWindow.FindName('CloseSettings').Add_Click({ $script:settingsWindow.Close() })
    $script:settingsWindow.FindName('ChoosePhoto').Add_Click({ Select-WidgetPhoto })
    $script:settingsWindow.FindName('ResetLayout').Add_Click({
        foreach ($row in $script:settingsRows.Values) { $row.x.Text = '0'; $row.y.Text = '0'; $row.scale.Value = 100 }
        $script:settingsWindow.FindName('ClockScale').Value = 100
        $script:resetClockPosition = $true
        $script:settingsWindow.FindName('SettingsStatus').Text = 'Layout reset is ready. Click Apply to save.'
    })
    $script:settingsWindow.FindName('ApplySettings').Add_Click({ Save-SettingsForm })
    $script:settingsWindow.Add_PreviewKeyDown({ param($sender,$e) if ($e.Key -eq 'Escape') { $sender.Close(); $e.Handled = $true } })
    $script:settingsWindow.Add_Closed({ $script:settingsWindow = $null })
    Set-SettingsForm
    return $script:settingsWindow
}
function Update-SettingsSample {
    if (-not $script:settingsWindow) { return }
    $theme = [string]$script:settingsWindow.FindName('Theme').SelectedItem
    $accent = [string]$script:settingsWindow.FindName('Accent').SelectedItem
    if (-not $script:widgetThemes.ContainsKey($theme) -or -not $script:widgetAccents.Contains($accent)) { return }
    $brush = [Windows.Media.LinearGradientBrush]::new()
    $brush.StartPoint = [Windows.Point]::new(0,0); $brush.EndPoint = [Windows.Point]::new(1,1)
    $brush.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString($script:widgetThemes[$theme][0]),0))
    $brush.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString($script:widgetThemes[$theme][2]),1))
    $brush.Opacity = $script:settingsWindow.FindName('GlassOpacity').Value / 100
    $script:settingsWindow.FindName('ThemeSample').Background = $brush
    $script:settingsWindow.FindName('AccentSample').Fill = [Windows.Media.BrushConverter]::new().ConvertFromString($script:widgetAccents[$accent])
}
function Set-SettingsForm {
    $p = $script:widgetPreferences; $w = $script:settingsWindow
    foreach ($name in @('Theme','Accent','TimeFormat','PhotoFit','WeatherUnits')) { $w.FindName($name).SelectedItem = $p[$name] }
    $w.FindName('DateFormat').SelectedItem = $w.FindName('DateFormat').Items | Where-Object Tag -eq $p.dateFormat
    $w.FindName('ClockStyle').SelectedItem = $script:selectedStyle; $w.FindName('ClockColor').SelectedItem = $script:selectedColor
    $w.FindName('GlassOpacity').Value = $p.glassOpacity * 100; $w.FindName('ClockScale').Value = $p.clockScale * 100
    $w.FindName('HideDelay').Value = $p.hideDelay; $w.FindName('NoteFont').Value = $p.noteFont
    $w.FindName('DockWidth').Value = $p.dockWidth
    $w.FindName('HideWindowsTaskbar').IsChecked = $p.hideWindowsTaskbar
    $w.FindName('Motion').IsChecked = $p.motion; $w.FindName('Seconds').IsChecked = $p.showSeconds; $w.FindName('Media').IsChecked = $p.showMedia
    foreach ($name in $script:settingsRows.Keys) {
        $row = $script:settingsRows[$name]; $choice = $p.widgets[$name]
        $row.enabled.IsChecked = $choice.enabled; $row.pinned.IsChecked = $choice.pinned; $row.scale.Value = $choice.scale * 100
        $row.x.Text = [Math]::Round($choice.x).ToString([Globalization.CultureInfo]::InvariantCulture)
        $row.y.Text = [Math]::Round($choice.y).ToString([Globalization.CultureInfo]::InvariantCulture)
    }
    $script:resetClockPosition = $false
    Update-SettingsSample
}
function Save-SettingsForm {
    $w = $script:settingsWindow
    try {
        $next = ConvertTo-WidgetPreferences ($script:widgetPreferences | ConvertTo-Json -Depth 6 | ConvertFrom-Json)
        foreach ($name in @('Theme','Accent','TimeFormat','PhotoFit','WeatherUnits','ClockStyle','ClockColor')) { $next[$name] = [string]$w.FindName($name).SelectedItem }
        $next.dateFormat = [string]$w.FindName('DateFormat').SelectedItem.Tag
        $next.glassOpacity = $w.FindName('GlassOpacity').Value / 100; $next.clockScale = $w.FindName('ClockScale').Value / 100
        $next.hideDelay = $w.FindName('HideDelay').Value; $next.noteFont = $w.FindName('NoteFont').Value
        $next.dockWidth = $w.FindName('DockWidth').Value
        $next.hideWindowsTaskbar = [bool]$w.FindName('HideWindowsTaskbar').IsChecked
        $next.motion = [bool]$w.FindName('Motion').IsChecked; $next.showSeconds = [bool]$w.FindName('Seconds').IsChecked; $next.showMedia = [bool]$w.FindName('Media').IsChecked
        foreach ($name in $script:settingsRows.Keys) {
            $row = $script:settingsRows[$name]; $choice = $next.widgets[$name]
            $choice.enabled = [bool]$row.enabled.IsChecked; $choice.pinned = [bool]$row.pinned.IsChecked; $choice.scale = $row.scale.Value / 100
            foreach ($axis in @('x','y')) {
                $number = 0.0
                if (-not [double]::TryParse($row[$axis].Text, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$number) -or [double]::IsNaN($number) -or [double]::IsInfinity($number) -or [Math]::Abs($number) -gt 10000) { throw "Enter a number between -10000 and 10000 for $($script:widgetLabels[$name]) $axis offset." }
                $choice[$axis] = $number
            }
        }
        if ($script:resetClockPosition) { $next.clockX = 0; $next.clockY = 0 }
        Save-WidgetPreferences $next
        $script:widgetPreferences = $next
        $script:selectedStyle = [string]$w.FindName('ClockStyle').SelectedItem; $script:selectedColor = [string]$w.FindName('ClockColor').SelectedItem
        Save-Appearance
        Apply-WidgetPreferences
        $script:resetClockPosition = $false
        $w.FindName('SettingsStatus').Text = 'Saved. Your desktop is ready.'
        $w.FindName('SettingsStatus').Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#BDECD6')
    } catch {
        $w.FindName('SettingsStatus').Text = $_.Exception.Message
        $w.FindName('SettingsStatus').Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#FFBEB8')
    }
}
function Show-WidgetSettings {
    if ($script:settingsWindow) { [void]$script:settingsWindow.Activate(); return }
    $form = New-WidgetSettingsWindow
    $form.MaxHeight = [Windows.SystemParameters]::WorkArea.Height
    $form.Height = [Math]::Min(780,$form.MaxHeight)
    $form.Show()
    [void]$form.Activate()
}
