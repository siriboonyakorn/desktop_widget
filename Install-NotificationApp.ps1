# Install the signed package. Trusting its public signing certificate is a separate,
# explicit administrator step. Developer Mode is never enabled by this installer.
$ErrorActionPreference = 'Stop'
$folder = Join-Path $PSScriptRoot 'installer'
$info = Get-Content -LiteralPath (Join-Path $folder 'installer-info.json') -Raw | ConvertFrom-Json
$packagePath = Join-Path $folder 'DesktopWidget.msix'
if ((Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash -ne $info.PackageSha256) { throw 'The package has changed since it was built.' }
$trusted = Get-Item -LiteralPath ("Cert:\LocalMachine\TrustedPeople\" + $info.CertificateThumbprint) -ErrorAction SilentlyContinue
if (-not $trusted) { throw 'First approve and run Trust-WidgetCertificate.ps1 as administrator. Developer Mode is not required.' }
Add-AppxPackage -Path $packagePath
Set-Content -LiteralPath (Join-Path $PSScriptRoot 'stop.request') -Value ''
$statusPath = Join-Path $PSScriptRoot 'status.json'
if (Test-Path -LiteralPath $statusPath) {
    $status = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
    $existing = Get-Process -Id $status.processId -ErrorAction SilentlyContinue
    if ($existing -and -not $existing.WaitForExit(5000)) { throw 'Close the running widget, then run Start Widget.vbs.' }
}
& (Join-Path $PSScriptRoot 'Start-DesktopWidget.ps1')
Write-Output 'Desktop Widget registered. Click Connect under the timeline to allow notification access.'
