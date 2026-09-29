# Run only after approving the local widget's signing certificate; requires admin.
# TrustedPeople trusts this signing certificate, not a new root certificate authority.
# Does not enable Developer Mode or change any execution/sideloading policy.
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
$folder = Join-Path $PSScriptRoot 'installer'
$info = Get-Content -LiteralPath (Join-Path $folder 'installer-info.json') -Raw | ConvertFrom-Json
$path = Join-Path $folder 'DesktopWidget.cer'
if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $info.CertificateSha256) { throw 'Signing certificate changed since the installer was built.' }
$cert = [Security.Cryptography.X509Certificates.X509Certificate2]::new($path)
try {
    if ($cert.Thumbprint -ne $info.CertificateThumbprint -or $cert.Subject -ne 'CN=DesktopWidget' -or $cert.HasPrivateKey) { throw 'Unexpected signing certificate.' }
    $constraints = $cert.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.19' }
    if (-not $constraints -or $constraints.CertificateAuthority) { throw 'Certificate must not be a certificate authority.' }
    Import-Certificate -FilePath $path -CertStoreLocation 'Cert:\LocalMachine\TrustedPeople' | Select-Object Subject,Thumbprint,NotAfter
} finally { $cert.Dispose() }
