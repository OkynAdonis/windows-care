[CmdletBinding()]
param([string]$BrowserPath)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not $BrowserPath) {
    $BrowserPath = @(
        'C:\Program Files\Google\Chrome\Application\chrome.exe',
        'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $BrowserPath) { throw 'Chrome ou Edge requis ; fournir -BrowserPath.' }
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('windows-care-web-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
try {
    $site = Join-Path $projectRoot 'site'
    $css = [IO.File]::ReadAllText((Join-Path $site 'styles.css'))
    # Tests hors reseau avec polices de repli ; ressources bitmap embarquees.
    $css = [regex]::Replace($css, '@import[^;]+;', '')
    $js = [IO.File]::ReadAllText((Join-Path $site 'motion.js'))
    $fixtures = @{}
    foreach ($name in @('index','guide')) {
        $html = [IO.File]::ReadAllText((Join-Path $site ($name + '.html')))
        $html = $html.Replace('<link rel="stylesheet" href="styles.css">', "<style>$css</style>")
        $html = $html.Replace('<script src="motion.js"></script>', "<script>$js</script>")
        $html = [regex]::Replace($html, '(src|href)="(assets/[^"]+)"', [Text.RegularExpressions.MatchEvaluator]{
            param($match)
            $image = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $site $match.Groups[2].Value)))
            return $match.Groups[1].Value + '="data:image/png;base64,' + $image + '"'
        })
        $fixtures[$name] = $html
    }
    $json = ($fixtures | ConvertTo-Json -Compress).Replace('</','<\/')
    $runner = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'site-browser.html')).Replace('__FIXTURES__',$json)
    $runnerPath = Join-Path $testRoot 'runner.html'
    [IO.File]::WriteAllText($runnerPath,$runner,[Text.UTF8Encoding]::new($false))
    $output = Join-Path $testRoot 'dom.html'
    $errors = Join-Path $testRoot 'browser.log'
    $profile = Join-Path $testRoot 'profile'
    $arguments = '--headless=new --disable-gpu --no-first-run --disable-background-networking --no-default-browser-check --user-data-dir="' + $profile + '" --dump-dom --virtual-time-budget=20000 "' + ([uri]$runnerPath).AbsoluteUri + '"'
    $process = Start-Process -FilePath $BrowserPath -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $output -RedirectStandardError $errors
    $dom = [IO.File]::ReadAllText($output)
    $result = [regex]::Match($dom,'<pre id="result">([^<]+)</pre>').Groups[1].Value
    if ($process.ExitCode -ne 0 -or $result -notlike 'PASS *') {
        $browserLog = if (Test-Path -LiteralPath $errors) { [IO.File]::ReadAllText($errors).Trim() } else { '' }
        if ($browserLog.Length -gt 2000) { $browserLog = $browserLog.Substring($browserLog.Length - 2000) }
        throw "Tests navigateur : $result. Code : $($process.ExitCode). Journal : $browserLog"
    }
    Write-Host $result
} finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ($resolved.StartsWith($tempBase,[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf) -like 'windows-care-web-*') {
        Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction SilentlyContinue
    }
}
