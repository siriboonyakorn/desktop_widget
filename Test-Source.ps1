$ErrorActionPreference = 'Stop'
$failed = @()
foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' -File) {
    $tokens = $null; $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    if ($errors.Count) { $failed += $file.Name; $errors | ForEach-Object { Write-Output $_.Message } }
}
if ($failed.Count) { throw ('PowerShell syntax errors in: ' + ($failed -join ', ')) }
Add-Type -Path (Join-Path $PSScriptRoot 'TopBarNative.cs')
Write-Output 'All PowerShell sources parse and the native menu helpers compile.'
