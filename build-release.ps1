[CmdletBinding()]
param([string]$Version = '1.0.1-rc.5')
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$site = Join-Path $projectRoot 'site'
$app = Join-Path $projectRoot 'app'
$release = Join-Path $projectRoot 'release'
$requiredFiles = @('SCRIPT_TOOL.bat','SCRIPT_TOOL.ps1','State.ps1','Health.ps1','Support.ps1','README')
if ($Version -notmatch '^\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?$') { throw 'Version invalide.' }
foreach ($name in $requiredFiles) {
    $source = if ($name -eq 'README') { Join-Path $projectRoot 'README.md' } else { Join-Path $app $name }
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Fichier requis absent : $name" }
}
# Les tests tournent dans un processus distinct et ne changent pas Windows.
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $projectRoot 'tests\Test-Tool.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Tests en echec : archive conservee, publication annulee.' }
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $projectRoot 'tests\Test-Launcher.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Tests du lanceur en echec : publication annulee.' }
$stage = Join-Path ([IO.Path]::GetTempPath()) ('windows-care-release-' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Force -Path $stage,$site,$release | Out-Null
    $payload = Join-Path $stage 'payload'
    New-Item -ItemType Directory -Path $payload | Out-Null
    foreach ($name in $requiredFiles) {
        $source = if ($name -eq 'README') { Join-Path $projectRoot 'README.md' } else { Join-Path $app $name }
        Copy-Item -LiteralPath $source -Destination (Join-Path $payload $name)
    }
    $candidate = Join-Path $stage 'SCRIPT_TOOL.zip'
    # Produire les memes octets a chaque build : ordre fixe et horodatage ZIP fixe.
    # Compress-Archive reprend les dates des fichiers et changeait donc le SHA-256 en CI.
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archiveStream = [IO.File]::Open($candidate,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try {
        $archive = [IO.Compression.ZipArchive]::new($archiveStream,[IO.Compression.ZipArchiveMode]::Create,$false)
        try {
            foreach ($name in $requiredFiles) {
                $entry = $archive.CreateEntry($name,[IO.Compression.CompressionLevel]::NoCompression)
                $entry.LastWriteTime = [DateTimeOffset]::new(2000,1,1,0,0,0,[TimeSpan]::Zero)
                $output = $entry.Open()
                try {
                    # Le checkout Git peut fournir LF ou CRLF selon la machine.
                    $content = [IO.File]::ReadAllText((Join-Path $payload $name),[Text.Encoding]::UTF8)
                    $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($content -replace "`r?`n","`r`n"))
                    $output.Write($bytes,0,$bytes.Length)
                } finally { $output.Dispose() }
            }
        } finally { $archive.Dispose() }
    } finally { $archiveStream.Dispose() }
    $info = Get-Item -LiteralPath $candidate
    $hash = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash
    $manifest = [ordered]@{Product='Windows Care'; Platform='TECH EXCHANGE'; Version=$Version; ReleaseDate=(Get-Date).ToString('yyyy-MM-dd'); Archive='SCRIPT_TOOL.zip'; SizeBytes=$info.Length; SizeKB=[math]::Round($info.Length/1KB,1); SHA256=$hash; Files=$requiredFiles}
    # Metadonnees generees dans le HTML : disponibles meme sans JavaScript.
    $size = $manifest.SizeKB.ToString('0.0',[Globalization.CultureInfo]::GetCultureInfo('fr-FR'))
    $date = (Get-Date).ToString('dd/MM/yyyy')
    $label = "ZIP · $size Ko · version $Version · $date"
    foreach ($name in @('index.html','guide.html')) {
        $page = Join-Path $site $name
        $html = [IO.File]::ReadAllText($page)
        if ($html -notmatch '<span data-release>.*?</span>') { throw "Marqueur de version absent : $name" }
        $html = [regex]::Replace($html,'<span data-release>.*?</span>',"<span data-release>$label</span>")
        $html = [regex]::Replace($html,'(<strong>Version de test publique[^<]*? )\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?(</strong>)', ('${1}' + $Version + '${2}'))
        $html = [regex]::Replace($html,'<code data-sha256>.*?</code>',"<code data-sha256>$hash</code>")
        [IO.File]::WriteAllText((Join-Path $stage $name),$html,[Text.UTF8Encoding]::new($false))
    }
    Copy-Item -LiteralPath $candidate -Destination (Join-Path $release 'SCRIPT_TOOL.zip') -Force
    Copy-Item -LiteralPath $candidate -Destination (Join-Path $site 'SCRIPT_TOOL.zip') -Force
    foreach ($name in @('index.html','guide.html')) { Copy-Item -LiteralPath (Join-Path $stage $name) -Destination (Join-Path $site $name) -Force }
    [IO.File]::WriteAllText((Join-Path $site 'version.json'), ($manifest | ConvertTo-Json -Depth 4), [Text.UTF8Encoding]::new($false))
    Write-Host "Release $Version : $size Ko | SHA-256 $hash"
} finally {
    $resolved = [IO.Path]::GetFullPath($stage)
    $tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ($resolved.StartsWith($tempBase,[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf) -like 'windows-care-release-*') {
        if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
    }
}
