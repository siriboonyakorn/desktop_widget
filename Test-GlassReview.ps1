$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'ClockWidget.ps1') -Preview
$review=[Windows.Window]::new();$review.Title='Glass panel visual review';$review.Width=720;$review.Height=680;$review.WindowStartupLocation='CenterScreen';$review.Background=[Windows.Media.BrushConverter]::new().ConvertFromString('#EEEDF5')
$grid=[Windows.Controls.Grid]::new();$review.Content=$grid
$text=[Windows.Controls.TextBlock]::new();$text.Text=('BACKGROUND DETAIL   0123456789   ' * 130);$text.TextWrapping='Wrap';$text.FontSize=23;$text.Foreground=[Windows.Media.Brushes]::DarkSlateBlue;$grid.Children.Add($text)|Out-Null
$anchor=[Windows.Controls.Button]::new();$anchor.Content='Open Control Center';$anchor.Width=170;$anchor.Height=30;$anchor.HorizontalAlignment='Right';$anchor.VerticalAlignment='Top';$anchor.Margin=[Windows.Thickness]::new(0,12,30,0);$grid.Children.Add($anchor)|Out-Null
$Preview=$false
$anchor.Add_Click({Show-TopPanel 'Control Center' $anchor})
$review.Add_ContentRendered({Show-TopPanel 'Control Center' $anchor})
$closeTimer=[Windows.Threading.DispatcherTimer]::new();$closeTimer.Interval=[TimeSpan]::FromSeconds(120);$closeTimer.Add_Tick({$review.Close()});$closeTimer.Start()
try{[void]$review.ShowDialog()}finally{$closeTimer.Stop();$script:topPanel.IsOpen=$false;foreach($e in $script:cornerCards){$e.Window.Close()}}
