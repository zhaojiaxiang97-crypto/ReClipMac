[CmdletBinding()]
param(
    [string]$QtRoot = "C:\Qt\6.8.3\msvc2022_64",
    [string]$Generator = "Visual Studio 17 2022",
    [ValidateSet("Win32", "x64", "ARM64")]
    [string]$Architecture = "x64"
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$thirdPartyRoot = Join-Path $repoRoot ".third_party"
$sourceRoot = Join-Path $thirdPartyRoot "src"
$buildRoot = Join-Path $thirdPartyRoot "build"
$installPrefix = Join-Path $thirdPartyRoot "install"

$ecmVersion = "v6.8.0"
$kirigamiVersion = "v6.8.0"
$ecmSource = Join-Path $sourceRoot "extra-cmake-modules"
$kirigamiSource = Join-Path $sourceRoot "kirigami"
$ecmBuild = Join-Path $buildRoot "ecm"
$kirigamiBuild = Join-Path $buildRoot "kirigami"

function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Command exited with code $LASTEXITCODE"
    }
}

if (-not (Test-Path (Join-Path $QtRoot "lib\cmake\Qt6\Qt6Config.cmake"))) {
    throw "Qt 6 installation not found under $QtRoot"
}

New-Item -ItemType Directory -Force $sourceRoot, $buildRoot, $installPrefix | Out-Null

if (-not (Test-Path (Join-Path $ecmSource ".git"))) {
    Invoke-Native "git" @(
        "clone", "--depth", "1", "--branch", $ecmVersion,
        "https://github.com/KDE/extra-cmake-modules.git", $ecmSource
    )
}

if (-not (Test-Path (Join-Path $kirigamiSource ".git"))) {
    Invoke-Native "git" @(
        "clone", "--depth", "1", "--branch", $kirigamiVersion,
        "https://github.com/KDE/kirigami.git", $kirigamiSource
    )
}

$installForCMake = $installPrefix -replace "\\", "/"
$qtForCMake = $QtRoot -replace "\\", "/"
$prefixPath = "$installForCMake;$qtForCMake"

Invoke-Native "cmake" @(
    "-S", $ecmSource,
    "-B", $ecmBuild,
    "-G", $Generator,
    "-A", $Architecture,
    "-DCMAKE_INSTALL_PREFIX=$installForCMake",
    "-DBUILD_TESTING=OFF"
)
Invoke-Native "cmake" @(
    "--build", $ecmBuild,
    "--config", "Release",
    "--target", "install"
)

Invoke-Native "cmake" @(
    "-S", $kirigamiSource,
    "-B", $kirigamiBuild,
    "-G", $Generator,
    "-A", $Architecture,
    "-DCMAKE_INSTALL_PREFIX=$installForCMake",
    "-DCMAKE_PREFIX_PATH=$prefixPath",
    "-DBUILD_SHARED_LIBS=ON",
    "-DBUILD_EXAMPLES=OFF",
    "-DBUILD_TESTING=OFF",
    "-DUSE_DBUS=OFF",
    "-DDESKTOP_ENABLED=ON",
    "-DBUILD_QCH=OFF"
)
Invoke-Native "cmake" @(
    "--build", $kirigamiBuild,
    "--config", "Release",
    "--target", "install",
    "--parallel", "4"
)

Write-Host "Kirigami $kirigamiVersion installed to $installPrefix"
Write-Host "Configure ReClipQt with: cmake -S . -B .build/windows-kirigami -DRECLIP_ENABLE_KIRIGAMI=ON"
