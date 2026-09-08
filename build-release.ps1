[CmdletBinding()]
param([string]$Version = '1.0.0')

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$site = Join-Path $root 'site'
$archive = Join-Path $root 'SCRIPT_TOOL.zip'
$siteArchive = Join-Path $site 'SCRIPT_TOOL.zip'
$versionFile = Join-Path $site 'version.json'
$requiredFiles = @('SCRIPT_TOOL.bat', 'SCRIPT_TOOL.ps1', 'README')

Write-Host 'TECH EXCHANGE / BUILD RELEASE'

foreach ($file in $requiredFiles) {
    $path = Join-Path $root $file
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Fichier requis absent : $file"
    }
}

$parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'SCRIPT_TOOL.ps1'), [ref]$null, [ref]$parseErrors) | Out-Null
if ($parseErrors.Count -gt 0) {
    $messages = ($parseErrors | ForEach-Object { $_.Message }) -join '; '
    throw "Syntaxe PowerShell invalide : $messages"
}

New-Item -ItemType Directory -Force -Path $site | Out-Null
Remove-Item -LiteralPath $archive, $siteArchive -Force -ErrorAction SilentlyContinue
Compress-Archive -Path ($requiredFiles | ForEach-Object { Join-Path $root $_ }) -DestinationPath $archive -CompressionLevel Optimal
Copy-Item -LiteralPath $archive -Destination $siteArchive -Force

$archiveInfo = Get-Item -LiteralPath $siteArchive
$hash = (Get-FileHash -LiteralPath $siteArchive -Algorithm SHA256).Hash
$manifest = [ordered]@{
    Product = 'Windows Care'
    Platform = 'TECH EXCHANGE'
    Version = $Version
    ReleaseDate = (Get-Date).ToString('yyyy-MM-dd')
    Archive = 'SCRIPT_TOOL.zip'
    SizeBytes = $archiveInfo.Length
    SizeKB = [math]::Round($archiveInfo.Length / 1KB, 1)
    SHA256 = $hash
    Files = $requiredFiles
}
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $versionFile -Encoding UTF8

Write-Host "Version : $Version"
Write-Host "Archive : $siteArchive"
Write-Host "Taille  : $($manifest.SizeKB) Ko"
Write-Host "SHA-256 : $hash"
Write-Host "Manifest: $versionFile"
