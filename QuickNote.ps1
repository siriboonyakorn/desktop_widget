# A single local note, with delayed atomic saves and no network or app permissions.
[xml]$noteXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 Title="Quick note widget" Width="214" Height="224" WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True"
 Background="Transparent" ShowInTaskbar="False" ShowActivated="False" Opacity="0" FontFamily="Segoe UI" Foreground="White">
 <Grid Margin="4,24,4,4">
  <Grid.RenderTransform><TranslateTransform x:Name="NoteSlide" Y="-20"/></Grid.RenderTransform>
  <Border x:Name="NoteGlass" CornerRadius="19" BorderThickness="1" Padding="14,12">
   <Grid>
    <Grid.RowDefinitions><RowDefinition Height="24"/><RowDefinition Height="*"/><RowDefinition Height="22"/></Grid.RowDefinitions>
    <TextBlock Text="QUICK NOTE" FontSize="11" FontWeight="SemiBold" Foreground="#DCE8FA"/>
    <Grid Grid.Row="1">
     <TextBox x:Name="NoteEditor" AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"
      Background="Transparent" Foreground="White" CaretBrush="White" SelectionBrush="#708BAACF" BorderThickness="0" Padding="0,2" FontSize="12"/>
     <TextBlock x:Name="NotePlaceholder" Text="Write something to remember..." TextWrapping="Wrap" FontSize="12" Foreground="#90DCE8FA" Margin="2,4,0,0" IsHitTestVisible="False"/>
    </Grid>
    <TextBlock x:Name="NoteStatus" Grid.Row="2" Text="Saved on this PC" Foreground="#AFC7E1" FontSize="9" VerticalAlignment="Bottom"/>
    <Button x:Name="NoteDone" Grid.Row="2" Content="Done" FontSize="10" HorizontalAlignment="Right" VerticalAlignment="Bottom" Focusable="False"/>
   </Grid>
  </Border>
  <Border Margin="2" CornerRadius="17" BorderThickness="0.7" BorderBrush="#28FFFFFF" IsHitTestVisible="False"/>
 </Grid>
</Window>
'@
$script:noteWindow = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($noteXaml))
$noteWindow.FindName('NoteGlass').Background = $glassSource.Background.Clone()
$noteWindow.FindName('NoteGlass').BorderBrush = $glassSource.BorderBrush.Clone()
$noteWindow.FindName('NoteDone').Style = $cornerTemplate.Resources['Nav']
$script:noteEditor = $noteWindow.FindName('NoteEditor')
$script:noteStatus = $noteWindow.FindName('NoteStatus')
$script:notePath = Join-Path $PSScriptRoot 'quick-note.txt'
$script:noteDirty = $false
$script:noteLoadFailed = $false
$script:noteEntry = @{ Name = 'QuickNote'; Window = $noteWindow; Slide = $noteWindow.FindName('NoteSlide'); Handle = [IntPtr]::Zero; Visible = $false; LastNear = [DateTime]::MinValue; Offset = 10; Anchor = 'Right'; TopOffset = 248; Editable = $true }
$script:cornerCards += $noteEntry
if (-not $Preview -and (Test-Path -LiteralPath $notePath)) {
    try { $noteEditor.Text = [IO.File]::ReadAllText($notePath, [Text.Encoding]::UTF8) }
    catch {
        $script:noteLoadFailed = $true; $noteEditor.IsReadOnly = $true
        $noteStatus.Text = 'Could not read saved note'
    }
}
$noteWindow.FindName('NotePlaceholder').Visibility = if ($noteEditor.Text.Length) { 'Collapsed' } else { 'Visible' }

function Save-QuickNote {
    if ($Preview -or -not $script:noteDirty -or $script:noteLoadFailed) { return }
    try {
        $temporary = $script:notePath + '.tmp'
        [IO.File]::WriteAllText($temporary, $noteEditor.Text, [Text.UTF8Encoding]::new($false))
        if ([IO.File]::Exists($script:notePath)) { [IO.File]::Replace($temporary, $script:notePath, [System.Management.Automation.Language.NullString]::Value) }
        else { [IO.File]::Move($temporary, $script:notePath) }
        $script:noteDirty = $false
        $noteStatus.Text = 'Saved on this PC'
    } catch { $noteStatus.Text = 'Not saved - click Done to retry'; $noteStatus.ToolTip = $_.Exception.Message }
}
$script:noteSaveTimer = [Windows.Threading.DispatcherTimer]::new()
$noteSaveTimer.Interval = [TimeSpan]::FromMilliseconds(600)
$noteSaveTimer.Add_Tick({ $script:noteSaveTimer.Stop(); Save-QuickNote })
$noteEditor.Add_TextChanged({
    $noteWindow.FindName('NotePlaceholder').Visibility = if ($noteEditor.Text.Length) { 'Collapsed' } else { 'Visible' }
    if ($Preview) { return }
    $script:noteDirty = $true
    $noteStatus.Text = 'Saving...'
    $script:noteSaveTimer.Stop(); $script:noteSaveTimer.Start()
})
$noteWindow.Add_Deactivated({ Save-QuickNote })
$noteWindow.FindName('NoteDone').Add_Click({ Save-QuickNote; [Windows.Input.Keyboard]::ClearFocus() })
$noteEditor.Add_PreviewKeyDown({
    param($sender, $eventArgs)
    if ($eventArgs.Key -eq 'Escape') { Save-QuickNote; [Windows.Input.Keyboard]::ClearFocus(); $eventArgs.Handled = $true }
})
