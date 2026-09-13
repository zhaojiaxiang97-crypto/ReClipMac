[CmdletBinding()]
param([string] $Proxy = '', [string] $OutputDirectory = '')

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$manifestPath = Join-Path $repoRoot 'runtime\python\dependencies.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$downloadDirectory = Join-Path $repoRoot '.artifacts\python-downloads'
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot ".third_party\python\windows-x64\$($manifest.python.version)"
}
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $downloadDirectory | Out-Null

function Get-VerifiedArtifact([string] $Url, [string] $Path, [string] $Algorithm, [string] $Expected) {
    if (-not (Test-Path -LiteralPath $Path)) {
        $curlArguments = @('--fail', '--location', '--retry', '3', '--output', $Path, $Url)
        if ($Proxy) { $curlArguments = @('--proxy', $Proxy) + $curlArguments }
        & curl.exe @curlArguments
        if ($LASTEXITCODE -ne 0) { throw "Download failed: $Url. Incomplete file retained at $Path." }
    }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm $Algorithm).Hash
    if ($actual -ine $Expected) { throw "Checksum mismatch: $Path. Retained for inspection; no extraction performed." }
}

$pythonArchive = Join-Path $downloadDirectory "python.$($manifest.python.version).nupkg"
$expectedPythonHash = [BitConverter]::ToString([Convert]::FromBase64String($manifest.python.sha512Base64)).Replace('-', '')
Get-VerifiedArtifact $manifest.python.url $pythonArchive 'SHA512' $expectedPythonHash
foreach ($wheel in $manifest.wheels) {
    Get-VerifiedArtifact $wheel.url (Join-Path $downloadDirectory $wheel.filename) 'SHA256' $wheel.sha256
}

$recordPath = Join-Path $OutputDirectory 'reclip-dependencies.json'
if (Test-Path -LiteralPath $OutputDirectory) {
    if ((Test-Path -LiteralPath $recordPath) -and
        (Get-FileHash -LiteralPath $recordPath).Hash -eq (Get-FileHash -LiteralPath $manifestPath).Hash -and
        (Test-Path -LiteralPath (Join-Path $OutputDirectory 'tools\include\Python.h')) -and
        (Test-Path -LiteralPath (Join-Path $OutputDirectory 'tools\Lib\site-packages\yt_dlp\__init__.py'))) {
        Write-Host "Pinned runtime already prepared: $OutputDirectory\tools"
        exit 0
    }
    throw "Output directory exists with incomplete/different contents. Choose a new -OutputDirectory: $OutputDirectory"
}

[IO.Compression.ZipFile]::ExtractToDirectory($pythonArchive, $OutputDirectory)
$sitePackages = Join-Path $OutputDirectory 'tools\Lib\site-packages'
New-Item -ItemType Directory -Force -Path $sitePackages | Out-Null
foreach ($wheel in $manifest.wheels) {
    [IO.Compression.ZipFile]::ExtractToDirectory((Join-Path $downloadDirectory $wheel.filename), $sitePackages)
}
Copy-Item -LiteralPath $manifestPath -Destination $recordPath
Write-Host "Pinned CPython/yt-dlp runtime ready. Set RECLIP_PYTHON_ROOT=$OutputDirectory\tools"
