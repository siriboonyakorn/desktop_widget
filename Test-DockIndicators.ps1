$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ClockWidget.ps1') -Preview
try {
    $script:macTaskNextPoll = [DateTime]::MinValue
    Update-MacDockTasks
    $macDockWindow.Opacity = 1; $script:macDockEntry.Slide.Y = 0
    $macDockWindow.Show(); $macDockWindow.UpdateLayout()
    $b = $script:macDockButtons[1]; $line=$b.Template.FindName('RunningDot',$b)
    [pscustomobject]@{ChromeWindows=@($script:macSlotTasks[1]).Count;Visibility=$line.Visibility;Width=$line.ActualWidth;Height=$line.ActualHeight;Position=$line.TranslatePoint([Windows.Point]::new(0,0),$b);ButtonHeight=$b.ActualHeight} | Format-List
    $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$macDockWindow.Width,[int]$macDockWindow.Height,96,96,[Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($macDockWindow)
    $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new(); $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream=[IO.File]::Create((Join-Path $PSScriptRoot 'preview-indicators.png')); try {$encoder.Save($stream)} finally {$stream.Dispose()}
} finally { foreach($entry in $script:cornerCards) {$entry.Window.Close()} }
