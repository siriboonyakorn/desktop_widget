$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ClockWidget.ps1') -Preview
$testDirectory = Join-Path ([IO.Path]::GetTempPath()) ('widget-photo-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testDirectory)
$script:photoSettingsPath = Join-Path $testDirectory 'settings.json'
try {
    $weather = $script:cornerCards | Where-Object Name -eq 'Weather'
    $photo = $script:photoEntry
    if ($photo.Window.Width -ne $weather.Window.Width -or $photo.Window.Height -ne $weather.Window.Height) { throw 'Photo size differs from weather' }
    $weatherPosition = Get-WidgetPlacement $weather
    $photoPosition = Get-WidgetPlacement $photo
    if ($photoPosition.Y -ne $weatherPosition.Y -or ($weatherPosition.X - $photoPosition.X - $photo.Window.Width) -ne 14) { throw 'Photo must sit beside weather with a 14-pixel gap' }
    $sample = Join-Path $testDirectory 'sample.png'
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'preview.png') -Destination $sample
    Set-WidgetPhoto $sample -Persist
    if ($photoWindow.FindName('PhotoPlaceholder').Visibility -ne 'Collapsed' -or -not $photoWindow.FindName('PhotoSurface').Fill) { throw 'Photo failed to render' }
    if ((Get-Content -LiteralPath $photoSettingsPath -Raw | ConvertFrom-Json).path -ne $sample) { throw 'Photo preference failed to persist' }
    Remove-Item -LiteralPath $sample
    $previous = $photoWindow.FindName('PhotoSurface').Fill
    try { Set-WidgetPhoto $sample -Persist; throw 'Missing image accepted' }
    catch { if ($_.Exception.Message -eq 'Missing image accepted') { throw } }
    if ($photoWindow.FindName('PhotoSurface').Fill -ne $previous) { throw 'Failed image replaced the existing photo' }
    Set-WidgetPhoto '' -Persist
    if ($photoWindow.FindName('PhotoPlaceholder').Visibility -ne 'Visible' -or $photoWindow.FindName('PhotoSurface').Fill) { throw 'Remove photo failed' }
    Start-CornerWidgets
    Set-CornerVisible $true $photo
    if (-not $photo.Visible -or $weather.Visible -or ([DesktopHost]::GetWindowLong($photo.Handle, -20) -band 0x20)) { throw 'Photo reveal must be independent and clickable' }
    Set-CornerVisible $false $photo
    if (-not ([DesktopHost]::GetWindowLong($photo.Handle, -20) -band 0x20)) { throw 'Hidden photo must pass clicks through' }
    $visual = [Windows.Media.DrawingVisual]::new()
    $drawing = $visual.RenderOpen()
    $x = 0
    foreach ($card in @($photo,$weather)) {
        $card.Window.BeginAnimation([Windows.UIElement]::OpacityProperty, $null)
        $card.Slide.BeginAnimation([Windows.Media.TranslateTransform]::YProperty, $null)
        $card.Window.Opacity = 1; $card.Slide.Y = 0
        $card.Window.UpdateLayout()
        $drawing.DrawRectangle([Windows.Media.VisualBrush]::new($card.Window), $null, [Windows.Rect]::new($x,0,214,244))
        $x += 228
    }
    $drawing.Close()
    $bitmap = [Windows.Media.Imaging.RenderTargetBitmap]::new(884,488,192,192,[Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($visual)
    $encoder = [Windows.Media.Imaging.PngBitmapEncoder]::new()
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream = [IO.File]::Create((Join-Path $PSScriptRoot 'preview-photo.png'))
    try { $encoder.Save($stream) } finally { $stream.Dispose() }
    Write-Output 'Photo sizing, placement, loading, persistence, unlocked files, failed-load retention, removal, and independent hover checks passed.'
} finally {
    if ($script:cornerTimer) { $script:cornerTimer.Stop() }
    foreach ($entry in $script:cornerCards) { $entry.Window.Close() }
    # Only the two known test files in the unique test directory are removed.
    foreach ($name in @('sample.png','settings.json')) {
        $path = Join-Path $testDirectory $name
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path }
    }
    [IO.Directory]::Delete($testDirectory)
}
