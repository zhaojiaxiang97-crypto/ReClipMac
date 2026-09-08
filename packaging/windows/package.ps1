[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',
    [string]$OutputDirectory = ''
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$qtRoot = if ($env:RECLIP_QT_ROOT) { $env:RECLIP_QT_ROOT } else { 'C:\Qt\6.8.3\msvc2022_64' }
$toolBin = if ($env:RECLIP_TOOL_BIN) { $env:RECLIP_TOOL_BIN } else { '' }
$qtCMake = Join-Path $qtRoot 'bin\qt-cmake.bat'
$windeployqt = Join-Path $qtRoot 'bin\windeployqt.exe'

if (-not (Test-Path -LiteralPath $qtCMake)) {
    $qtCMakeCommand = Get-Command qt-cmake.bat -ErrorAction SilentlyContinue
    if ($qtCMakeCommand) {
        $qtRoot = Split-Path (Split-Path $qtCMakeCommand.Source -Parent) -Parent
        $qtCMake = Join-Path $qtRoot 'bin\qt-cmake.bat'
        $windeployqt = Join-Path $qtRoot 'bin\windeployqt.exe'
    }
}

if (-not (Test-Path -LiteralPath $qtCMake)) {
    throw "Qt CMake was not found at $qtCMake. Set RECLIP_QT_ROOT to the Qt MSVC installation."
}
if (-not (Test-Path -LiteralPath $windeployqt)) {
    throw "windeployqt was not found at $windeployqt."
}
if ([string]::IsNullOrWhiteSpace($toolBin)) {
    $ytDlpCommand = Get-Command yt-dlp.exe -ErrorAction SilentlyContinue
    if ($ytDlpCommand) {
        $toolBin = Split-Path $ytDlpCommand.Source -Parent
    }
}
if (-not (Test-Path -LiteralPath $toolBin)) {
    throw "Runtime tool directory was not found. Set RECLIP_TOOL_BIN to a directory containing yt-dlp and FFmpeg."
}

$buildDirectory = Join-Path $repoRoot ".build\package-windows-$($Configuration.ToLowerInvariant())"
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
$env:Path = "$qtRoot\bin;$userPath;$machinePath"

& $qtCMake -S $repoRoot -B $buildDirectory -G 'Visual Studio 17 2022' -A x64
if ($LASTEXITCODE -ne 0) { throw "CMake configuration failed with exit code $LASTEXITCODE." }

& cmake --build $buildDirectory --config $Configuration --parallel 4
if ($LASTEXITCODE -ne 0) { throw "Release build failed with exit code $LASTEXITCODE." }

$sourceExecutable = Join-Path $buildDirectory "$Configuration\ReClip.exe"
if (-not (Test-Path -LiteralPath $sourceExecutable)) {
    throw "The built executable was not found at $sourceExecutable."
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot ".artifacts\windows\ReClip-$Configuration"
}
$packageDirectory = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $packageDirectory) {
    throw "Output directory already exists. Remove it explicitly or choose another -OutputDirectory: $packageDirectory"
}
New-Item -ItemType Directory -Force -Path (Split-Path $packageDirectory -Parent) | Out-Null
New-Item -ItemType Directory -Path $packageDirectory | Out-Null

$packageExecutable = Join-Path $packageDirectory 'ReClip.exe'
Copy-Item -LiteralPath $sourceExecutable -Destination $packageExecutable

& $windeployqt --release --qmldir (Join-Path $repoRoot 'qml') --no-translations $packageExecutable
if ($LASTEXITCODE -ne 0) { throw "windeployqt failed with exit code $LASTEXITCODE." }

# When the optional local Kirigami dependency is enabled, CMake copies its
# shared libraries and QML modules beside the build executable. Keep those
# files in the portable package as well; the app adds packageDirectory/qml to
# the QML import path at startup.
$buildOutputDirectory = Split-Path $sourceExecutable -Parent
Get-ChildItem -LiteralPath $buildOutputDirectory -Filter 'Kirigami*.dll' -File -ErrorAction SilentlyContinue |
    Copy-Item -Destination $packageDirectory
$kirigamiQmlSource = Join-Path $buildOutputDirectory 'qml\org'
if (Test-Path -LiteralPath $kirigamiQmlSource) {
    $packageQmlDirectory = Join-Path $packageDirectory 'qml'
    New-Item -ItemType Directory -Force -Path $packageQmlDirectory | Out-Null
    Copy-Item -LiteralPath $kirigamiQmlSource -Destination $packageQmlDirectory -Recurse -Force
}

$runtimeDirectory = Join-Path $packageDirectory 'bin'
$licenseDirectory = Join-Path $packageDirectory 'licenses'
New-Item -ItemType Directory -Path $runtimeDirectory,$licenseDirectory | Out-Null

foreach ($toolName in @('yt-dlp.exe', 'ffmpeg.exe', 'ffprobe.exe')) {
    $toolPath = Join-Path $toolBin $toolName
    if (-not (Test-Path -LiteralPath $toolPath)) {
        throw "Required runtime tool was not found at $toolPath."
    }
    Copy-Item -LiteralPath $toolPath -Destination (Join-Path $runtimeDirectory $toolName)
}

Get-ChildItem -LiteralPath $toolBin -Filter '*.dll' -File | Copy-Item -Destination $runtimeDirectory

Copy-Item -LiteralPath (Join-Path $repoRoot 'LICENSE') -Destination $licenseDirectory
Copy-Item -LiteralPath (Join-Path $repoRoot 'NOTICE') -Destination $licenseDirectory
Copy-Item -LiteralPath (Join-Path $repoRoot 'packaging\windows\THIRD_PARTY_NOTICES.md') -Destination $packageDirectory

$ffmpegLicense = Get-ChildItem -Path (Join-Path $toolBin '..') -Filter 'LICENSE.txt' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($ffmpegLicense) {
    Copy-Item -LiteralPath $ffmpegLicense.FullName -Destination (Join-Path $licenseDirectory 'FFmpeg-LICENSE.txt')
} else {
    Set-Content -LiteralPath (Join-Path $licenseDirectory 'FFmpeg-LICENSE-LOCATION.txt') -Encoding utf8 -Value 'Provide the FFmpeg LGPL license text from the exact FFmpeg build used for this package.'
}

$manifest = [ordered]@{
    application = 'Video Downloader'
    configuration = $Configuration
    qtRoot = $qtRoot
    ytDlp = 'bin/yt-dlp.exe'
    ffmpeg = 'bin/ffmpeg.exe'
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $packageDirectory 'runtime-manifest.json') -Encoding utf8

Write-Host "Portable package created at $packageDirectory"
