Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class WidgetFolders {
    [DllImport("shell32.dll")] static extern int SHGetKnownFolderPath(ref Guid id, uint flags, IntPtr token, out IntPtr path);
    public static string Downloads() {
        Guid id = new Guid("374DE290-123F-4565-9164-39C4925E467B"); IntPtr path;
        int result = SHGetKnownFolderPath(ref id, 0, IntPtr.Zero, out path);
        if (result != 0) return "";
        try { return Marshal.PtrToStringUni(path); } finally { Marshal.FreeCoTaskMem(path); }
    }
}
'@
$script:folderSettingsPath = Join-Path $PSScriptRoot 'folder-settings.json'
$script:quickFolderPaths = @([WidgetFolders]::Downloads(), [Environment]::GetFolderPath('MyDocuments'), [Environment]::GetFolderPath('MyPictures'), $PSScriptRoot)
if (Test-Path -LiteralPath $folderSettingsPath) {
    try {
        $savedFolders = Get-Content -LiteralPath $folderSettingsPath -Raw | ConvertFrom-Json
        for ($i = 0; $i -lt 4; $i++) { if ($i -lt $savedFolders.folders.Count) { $script:quickFolderPaths[$i] = [string]$savedFolders.folders[$i] } }
    } catch { }
}
[xml]$folderXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 Title="Quick folders widget" Width="70" Height="236" WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True"
 Background="Transparent" ShowInTaskbar="False" ShowActivated="False" Opacity="0" FontFamily="Segoe UI" Foreground="White">
 <Grid Margin="4">
  <Grid.RenderTransform><TranslateTransform x:Name="FolderSlide" X="20"/></Grid.RenderTransform>
  <Border x:Name="FolderGlass" CornerRadius="20" BorderThickness="1" Padding="7,8">
   <StackPanel>
    <TextBlock Text="FILES" FontSize="8" Foreground="#C7D9ED" HorizontalAlignment="Center" Margin="0,0,0,5"/>
    <StackPanel x:Name="FolderButtons"/>
   </StackPanel>
  </Border>
  <Border Margin="2" CornerRadius="18" BorderBrush="#28FFFFFF" BorderThickness="0.7" IsHitTestVisible="False"/>
 </Grid>
</Window>
'@
$script:folderWindow = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($folderXaml))
$folderWindow.FindName('FolderGlass').Background = $glassSource.Background.Clone()
$folderWindow.FindName('FolderGlass').BorderBrush = $glassSource.BorderBrush.Clone()
$script:folderEntry = @{ Name = 'QuickFolders'; Window = $folderWindow; Slide = $folderWindow.FindName('FolderSlide'); Handle = [IntPtr]::Zero; Visible = $false; LastNear = [DateTime]::MinValue; Offset = 4; Anchor = 'RightCenter'; Configuring = $false }
$script:cornerCards += $folderEntry
$script:folderButtons = @()

function Update-QuickFolders {
    for ($i = 0; $i -lt 4; $i++) {
        $button = $script:folderButtons[$i]; $path = $script:quickFolderPaths[$i]
        $button.Content = '+'; $button.ToolTip = 'Choose a folder'
        if (-not $path) { continue }
        $label = Split-Path -Path $path -Leaf
        if (-not $label) { $label = $path }
        $button.ToolTip = "$label`n$path`nRight-click to change"
        # Use the generic shell folder icon; avoid touching slow/offline custom paths during UI refresh.
        $icon = [DockNative]::IconFor($PSScriptRoot)
        if ($icon -ne [IntPtr]::Zero) {
            try {
                $image = [Windows.Controls.Image]::new(); $image.Width = 30; $image.Height = 30
                $source = [Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon($icon, [Windows.Int32Rect]::Empty, [Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions())
                $source.Freeze(); $image.Source = $source
                $image.RenderTransformOrigin = [Windows.Point]::new(0.5,0.5)
                $image.RenderTransform = [Windows.Media.ScaleTransform]::new(1,1)
                $button.Content = $image
            } finally { [void][DockNative]::DestroyIcon($icon) }
        }
    }
}

function Set-QuickFolder([int]$Slot, [string]$Path) {
    if ($Slot -lt 0 -or $Slot -ge 4 -or -not [IO.Path]::IsPathRooted($Path) -or -not [IO.Directory]::Exists($Path)) { throw 'Choose an existing folder.' }
    $old = $script:quickFolderPaths[$Slot]
    $script:quickFolderPaths[$Slot] = $Path
    try { @{ folders = @($script:quickFolderPaths) } | ConvertTo-Json | Set-Content -LiteralPath $folderSettingsPath -Encoding UTF8 }
    catch { $script:quickFolderPaths[$Slot] = $old; throw }
    Update-QuickFolders
}

function Select-QuickFolder([int]$Slot) {
    $script:folderEntry.Configuring = $true
    $picker = [Windows.Forms.FolderBrowserDialog]::new()
    try {
        $picker.Description = 'Choose folder ' + ($Slot + 1)
        $picker.ShowNewFolderButton = $false
        $picker.SelectedPath = $script:quickFolderPaths[$Slot]
        $owner = [Windows.Forms.NativeWindow]::new()
        $owner.AssignHandle($script:folderEntry.Handle)
        try { $result = $picker.ShowDialog($owner) } finally { $owner.ReleaseHandle() }
        if ($result -eq [Windows.Forms.DialogResult]::OK) { Set-QuickFolder $Slot $picker.SelectedPath }
    } catch { [void][Windows.MessageBox]::Show('The folder could not be saved. Please choose another folder or check the widget folder is writable.', 'Quick folders') }
    finally { $picker.Dispose(); $script:folderEntry.Configuring = $false; $script:folderEntry.LastNear = [DateTime]::Now }
}
$folderMenu = [Windows.Controls.ContextMenu]::new()
for ($i = 0; $i -lt 4; $i++) {
    $button = [Windows.Controls.Button]::new(); $button.Style = $cornerTemplate.Resources['Nav']
    $button.Width = 44; $button.Height = 46; $button.Margin = [Windows.Thickness]::new(0,2,0,2); $button.Tag = $i
    [Windows.Controls.ToolTipService]::SetPlacement($button,'Left')
    [Windows.Controls.ToolTipService]::SetInitialShowDelay($button,300)
    $button.Add_MouseEnter({ param($sender,$eventArgs) Set-DockHover $sender $true })
    $button.Add_MouseLeave({ param($sender,$eventArgs) Set-DockHover $sender $false })
    $button.Add_Click({
        param($sender,$eventArgs)
        $path = $script:quickFolderPaths[[int]$sender.Tag]
        if (-not $path) { Select-QuickFolder ([int]$sender.Tag); return }
        try {
            if (-not [IO.Directory]::Exists($path)) { throw 'Folder unavailable' }
            $start = [Diagnostics.ProcessStartInfo]::new($path)
            $start.UseShellExecute = $true
            [void][Diagnostics.Process]::Start($start)
        } catch { [void][Windows.MessageBox]::Show('This folder could not be opened. Right-click to choose another.', 'Quick folders') }
    })
    [void]$folderWindow.FindName('FolderButtons').Children.Add($button); $script:folderButtons += $button
    $item = [Windows.Controls.MenuItem]::new(); $item.Header = 'Change folder ' + ($i + 1) + '...'; $item.Tag = $i
    $item.Add_Click({ param($sender,$eventArgs) Select-QuickFolder ([int]$sender.Tag) })
    [void]$folderMenu.Items.Add($item)
}
$folderWindow.ContextMenu = $folderMenu
Update-QuickFolders
