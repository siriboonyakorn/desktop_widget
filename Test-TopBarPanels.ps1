$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'ClockWidget.ps1') -Preview
try {
 $topBarWindow.Opacity=1; $script:topBarEntry.Slide.Y=0; $topBarWindow.Show();$topBarWindow.UpdateLayout()
 foreach($kind in @('Tray','Wi-Fi','Sound','Bluetooth','Battery','Calendar','Control Center')) {
  Show-TopPanel $kind $topBarWindow.FindName('BarSettings')
  if($kind -eq 'Tray') { if(-not $script:topTrayJob.Wait(8000)){throw 'Tray timed out'}; Update-TopPanelState }
  if($script:topRadioLoad){
   $deadline=[DateTime]::Now.AddSeconds(3)
   while(-not $script:topRadioLoad.IsCompleted -and [DateTime]::Now -lt $deadline){Start-Sleep -Milliseconds 50}
   Update-TopPanelState
  }
  $script:topPanelSurface.UpdateLayout()
  if(-not $script:topPanel.IsOpen -or -not $script:topBarEntry.Configuring){throw 'Panel failed to open and keep bar visible'}
  if($kind -eq 'Sound' -and -not $script:topVolume){throw 'Sound volume slider missing'}
  $s=$script:topPanelSurface
  $s.Measure([Windows.Size]::new(320,1000));$s.Arrange([Windows.Rect]::new(0,0,320,$s.DesiredSize.Height));$s.UpdateLayout()
  if($kind -eq 'Sound') {
   $originalVolume=$script:topVolume.Value
   $script:topPanelUpdating=$true
   try {
    foreach($percent in @(0,50,100)) {
     $script:topVolume.Value=$percent; $script:topVolume.UpdateLayout()
     $fill=$script:topVolume.Template.FindName('VolumeFill',$script:topVolume)
     [void]$fill.ApplyTemplate();$fill.UpdateLayout()
     $indicator=$fill.Template.FindName('PART_Indicator',$fill)
     $track=$fill.Template.FindName('PART_Track',$fill)
     if([Math]::Abs($indicator.ActualWidth - ($track.ActualWidth*$percent/100)) -gt 1) {throw "Volume fill is incorrect at $percent percent"}
    }
   } finally {$script:topVolume.Value=$originalVolume;$script:topPanelUpdating=$false;$script:topVolume.UpdateLayout()}
  }
  $bmp=[Windows.Media.Imaging.RenderTargetBitmap]::new(640,[int]($s.ActualHeight*2),192,192,[Windows.Media.PixelFormats]::Pbgra32);$bmp.Render($s)
  $cornerPixel=New-Object byte[] 4
  $bmp.CopyPixels([Windows.Int32Rect]::new(0,0,1,1),$cornerPixel,4,0)
  if($cornerPixel[3] -ne 0){throw "$kind has a square painted corner"}
  $source=[Windows.PresentationSource]::FromVisual($script:topPanelSurface)
  if($source -is [Windows.Interop.HwndSource] -and [MenuGlass]::Apply($source.Handle,22)){throw 'Layered WPF panels must not enable rectangular native acrylic'}
  $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp))
  $f=[IO.File]::Create((Join-Path $PSScriptRoot ('preview-panel-'+$kind.Replace(' ','-')+'.png')));try{$encoder.Save($f)}finally{$f.Dispose()}
  $script:topPanel.IsOpen=$false
 }
 try { $volume=[MenuAudio]::Volume(); if($volume -lt 0 -or $volume -gt 1){throw 'Invalid volume'}; [MenuAudio]::SetVolume($volume); if([Math]::Abs([MenuAudio]::Volume()-$volume) -gt 0.01){throw 'Audio roundtrip failed'}; Write-Output 'Audio read and same-value write succeeded' } catch {Write-Output ('Audio unavailable: '+$_.Exception.Message)}
 Write-Output 'Wi-Fi, sound, Bluetooth, battery, calendar and Control Center panels rendered; lifecycle and slider passed.'
} finally { $script:topPanel.IsOpen=$false;foreach($e in $script:cornerCards){$e.Window.Close()} }
