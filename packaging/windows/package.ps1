[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',
    [string]$OutputDirectory = '',
    [switch]$EnableFfmpegSdk,
    [switch]$EnableYtDlpSdk
)

$ErrorActionPreference = 'Stop'
if ($EnableYtDlpSdk) { $EnableFfmpegSdk = $true }

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$qtRoot = if ($env:RECLIP_QT_ROOT) { $env:RECLIP_QT_ROOT } else { 'C:\Qt\6.8.3\msvc2022_64' }
$toolBin = if ($env:RECLIP_TOOL_BIN) { $env:RECLIP_TOOL_BIN } else { '' }
$ffmpegSdkRoot = if ($env:RECLIP_FFMPEG_ROOT) {
    $env:RECLIP_FFMPEG_ROOT
} else {
    Join-Path $repoRoot '.third_party\ffmpeg\windows-x64'
}
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
if (-not $EnableYtDlpSdk -and -not (Test-Path -LiteralPath $toolBin)) {
    throw "Runtime tool directory was not found. Set RECLIP_TOOL_BIN to a directory containing yt-dlp and FFmpeg."
}

$buildDirectory = if ($EnableYtDlpSdk) {
    Join-Path $repoRoot '.build\windows-ytdlp-sdk'
} else {
    Join-Path $repoRoot ".build\package-windows-$($Configuration.ToLowerInvariant())"
}
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
$env:Path = "$qtRoot\bin;$userPath;$machinePath"

$cmakeArguments = @(
    '-S', $repoRoot,
    '-B', $buildDirectory,
    '-G', 'Visual Studio 17 2022',
    '-A', 'x64'
)
$cmakeArguments += "-DRECLIP_ENABLE_YTDLP_SDK=$(if ($EnableYtDlpSdk) { 'ON' } else { 'OFF' })"
$cmakeArguments += "-DRECLIP_ENABLE_FFMPEG_SDK=$(if ($EnableFfmpegSdk) { 'ON' } else { 'OFF' })"
if ($EnableYtDlpSdk -and $env:RECLIP_PYTHON_ROOT) {
    $cmakeArguments += "-DRECLIP_PYTHON_ROOT=$env:RECLIP_PYTHON_ROOT"
}
if ($EnableFfmpegSdk) {
    $sdkIncludeDirectory = Test-Path -LiteralPath (Join-Path $ffmpegSdkRoot 'include')
    $sdkLibraryDirectory = Test-Path -LiteralPath (Join-Path $ffmpegSdkRoot 'lib')
    $sdkRuntimeDirectory = Test-Path -LiteralPath (Join-Path $ffmpegSdkRoot 'bin')
    if (-not $sdkIncludeDirectory -or -not $sdkLibraryDirectory -or -not $sdkRuntimeDirectory) {
        throw "FFmpeg SDK was not found at $ffmpegSdkRoot. Set RECLIP_FFMPEG_ROOT to a directory containing include, lib, and bin."
    }
    $cmakeArguments += @(
        '-DRECLIP_ENABLE_FFMPEG_SDK=ON',
        "-DRECLIP_FFMPEG_ROOT=$ffmpegSdkRoot"
    )
}
& $qtCMake @cmakeArguments
if ($LASTEXITCODE -ne 0) { throw "CMake configuration failed with exit code $LASTEXITCODE." }

& cmake --build $buildDirectory --config $Configuration --parallel 4
if ($LASTEXITCODE -ne 0) { throw "Release build failed with exit code $LASTEXITCODE." }

$sourceExecutable = Join-Path $buildDirectory "$Configuration\ReClip.exe"
if (-not (Test-Path -LiteralPath $sourceExecutable)) {
    throw "The built executable was not found at $sourceExecutable."
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $packageSuffix = if ($EnableYtDlpSdk) { '-ytdlp-sdk' } else { '' }
    $OutputDirectory = Join-Path $repoRoot ".artifacts\windows\ReClip-$Configuration$packageSuffix"
}
$packageDirectory = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $packageDirectory) {
    throw "Output directory already exists. Remove it explicitly or choose another -OutputDirectory: $packageDirectory"
}
New-Item -ItemType Directory -Force -Path (Split-Path $packageDirectory -Parent) | Out-Null
New-Item -ItemType Directory -Path $packageDirectory | Out-Null

$packageExecutable = Join-Path $packageDirectory 'ReClip.exe'
Copy-Item -LiteralPath $sourceExecutable -Destination $packageExecutable

& $windeployqt "--$($Configuration.ToLowerInvariant())" --qmldir (Join-Path $repoRoot 'qml') --no-translations $packageExecutable
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

$packagedTools = @()
if (-not $EnableYtDlpSdk) {
    $packagedTools += 'yt-dlp.exe'
    if (-not $EnableFfmpegSdk) {
        $packagedTools += 'ffprobe.exe'
    }
    # Keep command-line FFmpeg available as the explicit compatibility
    # fallback when only the FFmpeg SDK is enabled. ffprobe is provided by
    # FfprobeService in that configuration and is not copied into the package.
    $packagedTools += 'ffmpeg.exe'
}
foreach ($toolName in $packagedTools) {
    $toolPath = Join-Path $toolBin $toolName
    if (-not (Test-Path -LiteralPath $toolPath)) {
        throw "Required runtime tool was not found at $toolPath."
    }
    Copy-Item -LiteralPath $toolPath -Destination (Join-Path $runtimeDirectory $toolName)
}

if (-not $EnableYtDlpSdk) {
    Get-ChildItem -LiteralPath $toolBin -Filter '*.dll' -File | Copy-Item -Destination $runtimeDirectory
} else {
    $pythonRuntime = Join-Path $buildOutputDirectory 'runtime\python'
    if (-not (Test-Path -LiteralPath $pythonRuntime)) { throw "Embedded Python runtime missing: $pythonRuntime" }
    $packageRuntime = Join-Path $packageDirectory 'runtime'
    New-Item -ItemType Directory -Path $packageRuntime | Out-Null
    Copy-Item -LiteralPath $pythonRuntime -Destination $packageRuntime -Recurse
    Get-ChildItem -LiteralPath $buildOutputDirectory -Filter 'python*.dll' -File | Copy-Item -Destination $packageDirectory
    Copy-Item -LiteralPath (Join-Path $repoRoot 'runtime\python\dependencies.json') -Destination (Join-Path $licenseDirectory 'Python-dependencies.json')
}

if ($EnableFfmpegSdk) {
    Get-ChildItem -LiteralPath (Join-Path $ffmpegSdkRoot 'bin') -Filter '*.dll' -File |
        Copy-Item -Destination $packageDirectory
}

Copy-Item -LiteralPath (Join-Path $repoRoot 'LICENSE') -Destination $licenseDirectory
Copy-Item -LiteralPath (Join-Path $repoRoot 'NOTICE') -Destination $licenseDirectory
Copy-Item -LiteralPath (Join-Path $repoRoot 'packaging\windows\THIRD_PARTY_NOTICES.md') -Destination $packageDirectory

$ffmpegLicenseCandidates = @()
if ($toolBin) { $ffmpegLicenseCandidates += (Join-Path $toolBin '..') }
if ($EnableFfmpegSdk) {
    $ffmpegLicenseCandidates += $ffmpegSdkRoot
}
$ffmpegLicense = Get-ChildItem -Path $ffmpegLicenseCandidates -Filter 'LICENSE.txt' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($ffmpegLicense) {
    Copy-Item -LiteralPath $ffmpegLicense.FullName -Destination (Join-Path $licenseDirectory 'FFmpeg-LICENSE.txt')
} else {
    Set-Content -LiteralPath (Join-Path $licenseDirectory 'FFmpeg-LICENSE-LOCATION.txt') -Encoding utf8 -Value 'Provide the FFmpeg LGPL license text from the exact FFmpeg build used for this package.'
}
if ($EnableFfmpegSdk) {
    $sdkBuildInfo = Join-Path $ffmpegSdkRoot 'build-info.txt'
    if (Test-Path -LiteralPath $sdkBuildInfo) {
        Copy-Item -LiteralPath $sdkBuildInfo -Destination (Join-Path $licenseDirectory 'FFmpeg-SDK-build-info.txt')
    }
}

$manifest = [ordered]@{
    application = 'Video Downloader'
    configuration = $Configuration
    qtRoot = $qtRoot
    ytDlp = if ($EnableYtDlpSdk) { 'runtime/python/Lib/site-packages/yt_dlp' } else { 'bin/yt-dlp.exe' }
    ytDlpBackend = if ($EnableYtDlpSdk) { 'embedded-python-resolver-native-single-download' } else { 'process' }
    ffmpeg = if ($EnableYtDlpSdk) { $null } else { 'bin/ffmpeg.exe' }
    ffmpegBackend = if ($EnableYtDlpSdk) { 'embedded-sdk' } elseif ($EnableFfmpegSdk) { 'embedded-sdk-with-process-fallback' } else { 'process' }
    ffprobe = if ($EnableFfmpegSdk) { 'embedded-sdk/libavformat' } else { 'bin/ffprobe.exe' }
    ffprobeBackend = if ($EnableFfmpegSdk) { 'embedded-sdk' } else { 'process' }
    ffmpegSdkRoot = if ($EnableFfmpegSdk) { 'application-root' } else { $null }
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $packageDirectory 'runtime-manifest.json') -Encoding utf8

Write-Host "Portable package created at $packageDirectory"
