# Run in PowerShell 7. Creates a private local installer; changes no certificate stores.
$ErrorActionPreference = 'Stop'
$sdkFolder = Join-Path $PSScriptRoot 'tools\sdk\bin\10.0.26100.0\x64'
$makeAppx = Join-Path $sdkFolder 'makeappx.exe'
$signTool = Join-Path $sdkFolder 'signtool.exe'
if (-not (Test-Path -LiteralPath $makeAppx)) { throw 'Microsoft SDK packaging tools are missing from tools\sdk.' }
& (Join-Path $PSScriptRoot 'Build-NotificationApp.ps1')
$output = Join-Path $PSScriptRoot 'installer'
$stage = Join-Path $output 'package'
New-Item -ItemType Directory -Path $stage -Force | Out-Null
foreach ($file in @('DesktopWidget.exe','AppxManifest.xml','Logo.png','SmallLogo.png')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "NotificationApp\$file") -Destination $stage -Force
}
[IO.File]::WriteAllText((Join-Path $stage 'WidgetRoot.txt'), $PSScriptRoot)
$package = Join-Path $output 'DesktopWidget.msix'
& $makeAppx pack /d $stage /p $package /o
if ($LASTEXITCODE -ne 0) { throw 'MSIX packaging failed.' }
$rsa = [Security.Cryptography.RSA]::Create(3072)
$request = [Security.Cryptography.X509Certificates.CertificateRequest]::new('CN=DesktopWidget', $rsa, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
$request.CertificateExtensions.Add([Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]::new($false,$false,0,$true))
$request.CertificateExtensions.Add([Security.Cryptography.X509Certificates.X509KeyUsageExtension]::new([Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DigitalSignature,$true))
$usage = [Security.Cryptography.OidCollection]::new()
[void]$usage.Add([Security.Cryptography.Oid]::new('1.3.6.1.5.5.7.3.3'))
$request.CertificateExtensions.Add([Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]::new($usage,$true))
$certificate = $request.CreateSelfSigned([DateTimeOffset]::Now.AddMinutes(-5), [DateTimeOffset]::Now.AddYears(2))
$pfxPath = Join-Path $output 'temporary-signing-key.pfx'
$certificatePath = Join-Path $output 'DesktopWidget.cer'
$password = [Guid]::NewGuid().ToString('N') + [Guid]::NewGuid().ToString('N')
try {
    [IO.File]::WriteAllBytes($pfxPath, $certificate.Export([Security.Cryptography.X509Certificates.X509ContentType]::Pfx, $password))
    [IO.File]::WriteAllBytes($certificatePath, $certificate.Export([Security.Cryptography.X509Certificates.X509ContentType]::Cert))
    & $signTool sign /fd SHA256 /f $pfxPath /p $password $package
    if ($LASTEXITCODE -ne 0) { throw 'MSIX signing failed.' }
    [ordered]@{
        Package = 'DesktopWidget.msix'
        PackageSha256 = (Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash
        CertificateSha256 = (Get-FileHash -LiteralPath $certificatePath -Algorithm SHA256).Hash
        CertificateThumbprint = $certificate.Thumbprint
        Subject = $certificate.Subject
        Expires = $certificate.NotAfter.ToString('o')
        TrustStore = 'LocalMachine\TrustedPeople'
        DeveloperModeRequired = $false
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $output 'installer-info.json') -Encoding UTF8
} finally {
    if (Test-Path -LiteralPath $pfxPath) { Remove-Item -LiteralPath $pfxPath -Force }
    $certificate.Dispose(); $rsa.Dispose()
    $password = $null
}
Write-Output "Signed installer prepared: $package. No certificate trust settings changed."
