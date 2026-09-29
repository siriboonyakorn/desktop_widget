# Local photo frame, sharing the weather card's size and desktop hover behavior.
$script:photoSettingsPath = Join-Path $PSScriptRoot 'photo-settings.json'
[xml]$photoXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 Title="Photo glass widget" Width="214" Height="244" WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True"
 Background="Transparent" ShowInTaskbar="False" ShowActivated="False" Opacity="0" FontFamily="Segoe UI" Foreground="White">
 <Grid Margin="4,24,4,4" Cursor="Hand" ToolTip="Click to choose a photo">
  <Grid.RenderTransform><TranslateTransform x:Name="PhotoSlide" Y="-20"/></Grid.RenderTransform>
  <Border x:Name="PhotoGlass" CornerRadius="19" BorderThickness="1"/>
  <Rectangle x:Name="PhotoSurface" Margin="1" RadiusX="18" RadiusY="18" IsHitTestVisible="False"/>
  <StackPanel x:Name="PhotoPlaceholder" VerticalAlignment="Center" HorizontalAlignment="Center" IsHitTestVisible="False">
   <TextBlock Text="+" FontSize="36" FontWeight="Light" HorizontalAlignment="Center" Foreground="#D4EAFF"/>
   <TextBlock Text="ADD A PHOTO" FontSize="11" FontWeight="SemiBold" HorizontalAlignment="Center" Margin="0,8,0,0"/>
   <TextBlock x:Name="PhotoHint" Text="Click to choose" FontSize="10" Foreground="#C7D9ED" HorizontalAlignment="Center" Margin="0,5,0,0"/>
  </StackPanel>
  <Border Margin="2" CornerRadius="17" BorderBrush="#28FFFFFF" BorderThickness="0.7" IsHitTestVisible="False"/>
 </Grid>
</Window>
'@
$script:photoWindow = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($photoXaml))
$photoWindow.FindName('PhotoGlass').Background = $glassSource.Background.Clone()
$photoWindow.FindName('PhotoGlass').BorderBrush = $glassSource.BorderBrush.Clone()
$script:photoEntry = @{ Name = 'Photo'; Window = $photoWindow; Slide = $photoWindow.FindName('PhotoSlide'); Handle = [IntPtr]::Zero; Visible = $false; LastNear = [DateTime]::MinValue; Offset = (10 + $weatherWindow.Width + 14); Anchor = 'Right'; Configuring = $false }
$script:cornerCards += $photoEntry
$script:photoPath = ''

function Set-WidgetPhoto([string]$Path, [switch]$Persist) {
    $brush = $null
    if ($Path) {
        # Load fully before closing the stream so the original photo is never locked.
        $stream = [IO.File]::OpenRead($Path)
        try {
            $bitmap = [Windows.Media.Imaging.BitmapImage]::new()
            $bitmap.BeginInit()
            $bitmap.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bitmap.DecodePixelWidth = 1024
            $bitmap.StreamSource = $stream
            $bitmap.EndInit()
            $bitmap.Freeze()
        } finally { $stream.Dispose() }
        $brush = [Windows.Media.ImageBrush]::new($bitmap)
        $brush.Stretch = if ($script:widgetPreferences -and $script:widgetPreferences.photoFit -eq 'Fit') { 'Uniform' } else { 'UniformToFill' }
        $brush.Freeze()
    }
    if ($Persist) {
        @{ path = $Path } | ConvertTo-Json | Set-Content -LiteralPath $script:photoSettingsPath -Encoding UTF8 -ErrorAction Stop
    }
    $script:photoPath = $Path
    $photoWindow.FindName('PhotoSurface').Fill = $brush
    $photoWindow.FindName('PhotoPlaceholder').Visibility = if ($brush) { 'Collapsed' } else { 'Visible' }
    $photoWindow.FindName('PhotoHint').Text = 'Click to choose'
    $photoWindow.FindName('PhotoGlass').Parent.ToolTip = if ($brush) { 'Click to change photo. Ctrl+drag to move.' } else { 'Click to choose a photo. Ctrl+drag to move.' }
}

function Select-WidgetPhoto {
    $script:photoEntry.Configuring = $true
    $picker = [Microsoft.Win32.OpenFileDialog]::new()
    $picker.Title = 'Choose a photo'
    $picker.Filter = 'Photos (*.jpg;*.jpeg;*.png;*.bmp;*.gif;*.tif;*.tiff)|*.jpg;*.jpeg;*.png;*.bmp;*.gif;*.tif;*.tiff'
    try {
        $owner = if ($script:settingsWindow) { $script:settingsWindow } else { $photoWindow }
        if ($picker.ShowDialog($owner)) { Set-WidgetPhoto $picker.FileName -Persist }
    } catch {
        [void][Windows.MessageBox]::Show($photoWindow, 'The photo could not be loaded or saved. Choose another image and check that the widget folder is writable.', 'Photo widget')
    } finally {
        $script:photoEntry.Configuring = $false
        $script:photoEntry.LastNear = [DateTime]::Now
    }
}
$photoWindow.Add_MouseLeftButtonUp({ Select-WidgetPhoto })
$photoMenu = [Windows.Controls.ContextMenu]::new()
$choosePhoto = [Windows.Controls.MenuItem]::new()
$choosePhoto.Header = 'Choose photo...'
$choosePhoto.Add_Click({ Select-WidgetPhoto })
[void]$photoMenu.Items.Add($choosePhoto)
$clearPhoto = [Windows.Controls.MenuItem]::new()
$clearPhoto.Header = 'Remove photo'
$clearPhoto.Add_Click({
    try { Set-WidgetPhoto '' -Persist }
    catch { [void][Windows.MessageBox]::Show($photoWindow, 'The photo preference could not be saved.', 'Photo widget') }
})
[void]$photoMenu.Items.Add($clearPhoto)
$photoWindow.ContextMenu = $photoMenu
if (-not $Preview -and (Test-Path -LiteralPath $photoSettingsPath)) {
    try {
        $savedPhoto = Get-Content -LiteralPath $photoSettingsPath -Raw -ErrorAction Stop | ConvertFrom-Json
        Set-WidgetPhoto ([string]$savedPhoto.path)
    } catch { $photoWindow.FindName('PhotoHint').Text = 'Photo unavailable - choose again' }
}
