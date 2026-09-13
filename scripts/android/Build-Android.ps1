param(
    [ValidateSet("arm64-v8a", "x86_64")]
    [string] $Abi = "arm64-v8a",
    [ValidateSet("Debug", "Release")]
    [string] $BuildType = "Debug",
    [string] $QtVersion = "6.8.3",
    [string] $QtRoot = "C:\Qt",
    [string] $AndroidSdkRoot = "C:\Android\sdk",
    [string] $NdkVersion = "26.1.10909125",
    [string] $AndroidPlatform = "android-34",
    [string] $JavaHome = "",
    [ValidateRange(1, 64)]
    [int] $Parallel = 4,
    [ValidatePattern('^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$')]
    [string] $ApplicationId = "com.reclip.videodownloader",
    [string] $AppName = "Video Downloader",
    [string] $BuildDir = "",
    [switch] $WithYtDlpAndroid,
    [string] $YtDlpAarPath = "",
    [switch] $WithAndroidFfmpegKit,
    [string] $FfmpegKitAarPath = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\")).Path

# Prefer an explicit JDK, then a working JAVA_HOME, then the project-local
# toolchain. A stale system JAVA_HOME must not hide a usable local JDK.
if ([string]::IsNullOrWhiteSpace($JavaHome)) {
    if ($env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME "bin\javac.exe"))) {
        $JavaHome = $env:JAVA_HOME
    } else {
        $localJdk = Get-ChildItem (Join-Path $repoRoot ".third_party\java") -Directory -Filter "jdk-17*" -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending | Select-Object -First 1
        if ($localJdk) { $JavaHome = $localJdk.FullName }
    }
}
if ([string]::IsNullOrWhiteSpace($JavaHome) -or -not (Test-Path (Join-Path $JavaHome "bin\javac.exe"))) {
    throw "A JDK is required. Install JDK 17 and pass -JavaHome or set JAVA_HOME."
}
$env:JAVA_HOME = (Resolve-Path $JavaHome).Path
$env:PATH = (Join-Path $env:JAVA_HOME "bin") + [IO.Path]::PathSeparator + $env:PATH
# Use a real project-local temporary path. Windows packaged terminals can
# expose a virtualized TEMP where Java NIO's Unix-domain loopback fails.
$javaTemp = Join-Path $repoRoot ".scratch\android-java-tmp"
New-Item -ItemType Directory -Force -Path $javaTemp | Out-Null
$env:TEMP = $javaTemp
$env:TMP = $javaTemp
if ([string]::IsNullOrWhiteSpace($env:GRADLE_USER_HOME)) {
    $env:GRADLE_USER_HOME = Join-Path $repoRoot ".third_party\gradle-cache"
}
# androiddeployqt invokes Gradle without --no-daemon. A persistent child can
# keep PowerShell's redirected output pipe open after CMake has finished.
$env:GRADLE_OPTS = "$env:GRADLE_OPTS -Dorg.gradle.daemon=false".Trim()

$targetArch = if ($Abi -eq "arm64-v8a") { "android_arm64_v8a" } else { "android_x86_64" }
$qtHost = Join-Path $QtRoot "$QtVersion\msvc2022_64"
$qtTarget = Join-Path $QtRoot "$QtVersion\$targetArch"
$ndkRoot = Join-Path $AndroidSdkRoot "ndk\$NdkVersion"
$cmakePackageDir = Join-Path $qtTarget "lib\cmake\Qt6"
$toolchain = Join-Path $ndkRoot "build\cmake\android.toolchain.cmake"

if ([string]::IsNullOrWhiteSpace($BuildDir)) {
    $safeAbi = $Abi.Replace("-", "_")
    $BuildDir = Join-Path $repoRoot ".build\android-$safeAbi-$BuildType"
}

$androidPackageSource = Join-Path $repoRoot "android"
$needsStagedAndroidPackage = $WithYtDlpAndroid -or $WithAndroidFfmpegKit -or $AppName -ne "Video Downloader"
if ($needsStagedAndroidPackage) {
    $androidPackageSource = Join-Path $BuildDir "android-package"
    New-Item -ItemType Directory -Force -Path $androidPackageSource | Out-Null
    Copy-Item -Path (Join-Path $repoRoot "android\*") -Destination $androidPackageSource -Recurse -Force
    $androidLibDirectory = Join-Path $androidPackageSource "libs"
    New-Item -ItemType Directory -Force -Path $androidLibDirectory | Out-Null
    $stringsPath = Join-Path $androidPackageSource "res\values\strings.xml"
    [xml]$strings = Get-Content -LiteralPath $stringsPath -Encoding UTF8
    $strings.SelectSingleNode('/resources/string[@name="app_name"]').InnerText = $AppName
    $strings.Save($stringsPath)
}

if ($WithYtDlpAndroid) {
    if ([string]::IsNullOrWhiteSpace($YtDlpAarPath)) {
        $fetchScript = Join-Path $repoRoot "scripts\android\Fetch-AndroidYtDlp.ps1"
        & pwsh -NoProfile -File $fetchScript
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to fetch the Android yt-dlp AAR."
        }
        $YtDlpAarPath = Join-Path $repoRoot ".artifacts\android-runtime\yt-dlp-android-2.0.2\yt-dlp-android-2.0.2.aar"
    }

    if (-not (Test-Path -LiteralPath $YtDlpAarPath)) {
        throw "The Android yt-dlp AAR does not exist: $YtDlpAarPath"
    }

    Copy-Item -LiteralPath $YtDlpAarPath -Destination (Join-Path $androidLibDirectory "yt-dlp-android.aar") -Force
    $optionalBridge = Join-Path $repoRoot "android\optional-src\com\reclip\videodownloader\AndroidYtDlpBridge.java"
    $stagedBridgeDirectory = Join-Path $androidPackageSource "src\com\reclip\videodownloader"
    if (-not (Test-Path -LiteralPath $optionalBridge)) {
        throw "The Android yt-dlp bridge source does not exist: $optionalBridge"
    }
    New-Item -ItemType Directory -Force -Path $stagedBridgeDirectory | Out-Null
    Copy-Item -LiteralPath $optionalBridge -Destination $stagedBridgeDirectory -Force
    Write-Host "Staged Android yt-dlp AAR: $YtDlpAarPath"
}

if ($WithAndroidFfmpegKit) {
    if ([string]::IsNullOrWhiteSpace($FfmpegKitAarPath)) {
        $fetchScript = Join-Path $repoRoot "scripts\android\Fetch-AndroidFfmpegKit.ps1"
        & pwsh -NoProfile -File $fetchScript
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to fetch the Android FFmpegKit full AAR."
        }
        $FfmpegKitAarPath = Join-Path $repoRoot ".artifacts\android-runtime\ffmpeg-kit-full-8.1.7\ffmpeg-kit-full-8.1.7-arm64-v8a-x86_64.aar"
    }

    if (-not (Test-Path -LiteralPath $FfmpegKitAarPath)) {
        throw "The Android FFmpegKit full AAR does not exist: $FfmpegKitAarPath"
    }

    Copy-Item -LiteralPath $FfmpegKitAarPath -Destination (Join-Path $androidLibDirectory "ffmpeg-kit-full.aar") -Force
    $ffmpegKitArtifactDirectory = Split-Path -Parent $FfmpegKitAarPath
    foreach ($supportingArtifactName in @(
        "smart-exception-common-0.2.1.jar",
        "smart-exception-java-0.2.1.jar"
    )) {
        $supportingArtifactPath = Join-Path $ffmpegKitArtifactDirectory $supportingArtifactName
        if (-not (Test-Path -LiteralPath $supportingArtifactPath)) {
            throw "The Android FFmpegKit support artifact does not exist: $supportingArtifactPath"
        }
        Copy-Item -LiteralPath $supportingArtifactPath -Destination (Join-Path $androidLibDirectory $supportingArtifactName) -Force
    }
    Write-Host "Staged Android FFmpegKit full AAR: $FfmpegKitAarPath"
}

function Resolve-Executable([string] $Name, [string[]] $Candidates) {
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    foreach ($candidate in $Candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    throw "Unable to find $Name. Install the required tool or pass it through PATH."
}

$cmake = Resolve-Executable "cmake" @(
    (Join-Path $QtRoot "Tools\CMake_64\bin\cmake.exe"),
    "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
)
$ninja = Resolve-Executable "ninja" @(
    (Join-Path $QtRoot "Tools\Ninja\ninja.exe"),
    "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja\ninja.exe"
)

foreach ($requiredPath in @($qtHost, $qtTarget, $AndroidSdkRoot, $ndkRoot, $cmakePackageDir, $toolchain)) {
    if (-not (Test-Path $requiredPath)) {
        throw "Required Android build path does not exist: $requiredPath"
    }
}

$env:ANDROID_SDK_ROOT = $AndroidSdkRoot
$env:ANDROID_HOME = $AndroidSdkRoot

$cmakeArgs = @(
    "-S", $repoRoot,
    "-B", $BuildDir,
    "-G", "Ninja",
    "-DCMAKE_MAKE_PROGRAM=$ninja",
    "-DCMAKE_BUILD_TYPE=$BuildType",
    "-DCMAKE_TOOLCHAIN_FILE=$toolchain",
    "-DANDROID_ABI=$Abi",
    "-DANDROID_PLATFORM=$AndroidPlatform",
    "-DANDROID_SDK_ROOT=$AndroidSdkRoot",
    "-DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=BOTH",
    "-DCMAKE_PREFIX_PATH=$qtTarget;$qtHost",
    "-DQt6_DIR=$cmakePackageDir",
    "-DQT_HOST_PATH=$qtHost",
    "-DRECLIP_ENABLE_KIRIGAMI=OFF",
    "-DRECLIP_ANDROID_PACKAGE_SOURCE_DIR=$androidPackageSource",
    "-DRECLIP_ANDROID_APPLICATION_ID=$ApplicationId",
    "-DBUILD_TESTING=OFF"
)

Write-Host "Configuring Video Downloader for Android $Abi ($BuildType)..."
& $cmake @cmakeArgs
if ($LASTEXITCODE -ne 0) {
    throw "CMake configuration failed with exit code $LASTEXITCODE."
}

Write-Host "Building Android APK..."
& $cmake "--build" $BuildDir "--parallel" $Parallel
if ($LASTEXITCODE -ne 0) {
    throw "Android build failed with exit code $LASTEXITCODE."
}

if ($WithAndroidFfmpegKit) {
    # androiddeployqt copies local AARs into the generated package, but it
    # does not copy the standalone smart-exception JARs required by the
    # FFmpegKit Java classes. Add them to the final Gradle project and run
    # the Android packaging task once more so the runtime dependency is
    # present in the APK.
    $generatedLibDirectory = Join-Path $BuildDir "android-build\libs"
    New-Item -ItemType Directory -Force -Path $generatedLibDirectory | Out-Null
    $ffmpegKitArtifactDirectory = Split-Path -Parent $FfmpegKitAarPath
    foreach ($supportingArtifactName in @(
        "smart-exception-common-0.2.1.jar",
        "smart-exception-java-0.2.1.jar"
    )) {
        $supportingArtifactPath = Join-Path $ffmpegKitArtifactDirectory $supportingArtifactName
        if (-not (Test-Path -LiteralPath $supportingArtifactPath)) {
            throw "The generated Android package is missing FFmpegKit support artifact: $supportingArtifactPath"
        }
        Copy-Item -LiteralPath $supportingArtifactPath -Destination (Join-Path $generatedLibDirectory $supportingArtifactName) -Force
    }

    $gradleWrapper = (Resolve-Path (Join-Path $BuildDir "android-build\gradlew.bat")).Path
    if (-not (Test-Path -LiteralPath $gradleWrapper)) {
        throw "The generated Android Gradle wrapper does not exist: $gradleWrapper"
    }

    Push-Location (Split-Path -Parent $gradleWrapper)
    try {
        & $gradleWrapper "assemble$BuildType" "--no-daemon"
        if ($LASTEXITCODE -ne 0) {
            throw "Android Gradle packaging failed with exit code $LASTEXITCODE."
        }
    } finally {
        Pop-Location
    }
}

$apk = Join-Path $BuildDir "android-build\build\outputs\apk\$($BuildType.ToLowerInvariant())\android-build-$($BuildType.ToLowerInvariant()).apk"
if (-not (Test-Path $apk)) {
    throw "Build completed but the APK was not found at $apk"
}

Write-Host "APK: $apk"
