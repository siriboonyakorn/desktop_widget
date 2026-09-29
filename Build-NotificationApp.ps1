$ErrorActionPreference = 'Stop'
$folder = Join-Path $PSScriptRoot 'NotificationApp'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $compiler /nologo /target:winexe /platform:x64 "/out:$folder\DesktopWidget.exe" "$folder\Launcher.cs"
if ($LASTEXITCODE -ne 0) { throw 'Could not build notification launcher.' }
Add-Type -AssemblyName System.Drawing
foreach ($size in @(150,44)) {
    $bitmap = [Drawing.Bitmap]::new($size,$size)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = 'AntiAlias'
    $graphics.Clear([Drawing.Color]::FromArgb(47,62,83))
    $pen = [Drawing.Pen]::new([Drawing.Color]::White, [single]($size / 22))
    $graphics.DrawEllipse($pen, [single]($size * .18), [single]($size * .18), [single]($size * .64), [single]($size * .64))
    $graphics.DrawLine($pen, [single]($size * .5), [single]($size * .3), [single]($size * .5), [single]($size * .5))
    $graphics.DrawLine($pen, [single]($size * .5), [single]($size * .5), [single]($size * .68), [single]($size * .57))
    $name = if ($size -eq 150) { 'Logo.png' } else { 'SmallLogo.png' }
    $bitmap.Save((Join-Path $folder $name), [Drawing.Imaging.ImageFormat]::Png)
    $pen.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
}
