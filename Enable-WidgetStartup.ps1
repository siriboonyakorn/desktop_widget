$ErrorActionPreference = 'Stop'

$launcher = Join-Path $PSScriptRoot 'Start Widget.vbs'
if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) {
    throw "Widget launcher is missing: $launcher"
}

$shell = New-Object -ComObject WScript.Shell
$hostPath = Join-Path $env:WINDIR 'System32\wscript.exe'
foreach ($folderName in @('Desktop', 'Startup')) {
    $folder = [Environment]::GetFolderPath($folderName)
    if (-not $folder -or -not (Test-Path -LiteralPath $folder -PathType Container)) {
        throw "Windows $folderName folder is unavailable."
    }
    $path = Join-Path $folder 'Desktop Widgets.lnk'
    $shortcut = $shell.CreateShortcut($path)
    $shortcut.TargetPath = $hostPath
    $shortcut.Arguments = '"' + $launcher + '"'
    $shortcut.WorkingDirectory = $PSScriptRoot
    $shortcut.WindowStyle = 7
    $shortcut.IconLocation = (Join-Path $env:WINDIR 'System32\shell32.dll') + ',20'
    $shortcut.Description = 'Start the desktop clock and widgets'
    $shortcut.Save()

    $saved = $shell.CreateShortcut($path)
    if ($saved.TargetPath -ne $hostPath -or $saved.Arguments -ne ('"' + $launcher + '"')) {
        throw "Shortcut verification failed: $path"
    }
    Write-Output "Verified: $path"
}
