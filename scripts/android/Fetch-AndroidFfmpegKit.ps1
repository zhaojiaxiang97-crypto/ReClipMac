[CmdletBinding()]
param(
    [string] $OutputDirectory = "",
    [switch] $Force
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot ".artifacts\android-runtime\ffmpeg-kit-full-8.1.7"
}

$version = "8.1.7"
$artifact = "ffmpeg-kit-full-$version-arm64-v8a-x86_64.aar"
$expectedSha256 = "C3CBC81D498175FD2AA69EE2DFE7DAFBF519052A96283C2568FE5B3B16618456"
# Pin the maintained GitHub release asset so the Android runtime source is
# visible and reproducible. The asset contains arm64-v8a and x86_64, which
# covers the supported phone and emulator builds.
$sourceUrl = "https://github.com/ffmpegkit-maintained/ffmpeg/releases/download/v$version-lts-android/$artifact"
$targetPath = Join-Path $OutputDirectory $artifact
$temporaryPath = Join-Path $OutputDirectory "$artifact.download"
$supportingArtifacts = @(
    @{
        Name = "smart-exception-common-0.2.1.jar"
        Url = "https://repo.maven.apache.org/maven2/com/arthenica/smart-exception-common/0.2.1/smart-exception-common-0.2.1.jar"
        Sha256 = "1CAD0FB4DFA01755A014331B5ED199281D2C3FAB5ACA5C9D7ABD0B41D0EC3F7B"
    },
    @{
        Name = "smart-exception-java-0.2.1.jar"
        Url = "https://repo.maven.apache.org/maven2/com/arthenica/smart-exception-java/0.2.1/smart-exception-java-0.2.1.jar"
        Sha256 = "5B96AAA5F191DEDBEF72FB0C38F1A2B01807920AFC0D92A75A2ACD6E0CC7703C"
    }
)

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

if ((Test-Path -LiteralPath $targetPath) -and -not $Force) {
    $existingHash = (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash
    if ($existingHash -ieq $expectedSha256) {
        Write-Host "Android FFmpegKit full $version is already available and verified."
        Write-Host "Path: $targetPath"
        Write-Host "SHA-256: $existingHash"
    } else {
        throw "Existing FFmpegKit full checksum does not match the pinned artifact: $targetPath"
    }
} else {
    if (Test-Path -LiteralPath $temporaryPath) {
        Remove-Item -LiteralPath $temporaryPath -Force
    }

    Write-Host "Downloading Android FFmpegKit full $version from the maintained GitHub release..."
    & curl.exe -L --fail --retry 5 --retry-delay 2 --output $temporaryPath $sourceUrl
    if ($LASTEXITCODE -ne 0) {
        throw "FFmpegKit full download failed with exit code $LASTEXITCODE."
    }

    $actualHash = (Get-FileHash -LiteralPath $temporaryPath -Algorithm SHA256).Hash
    if ($actualHash -ine $expectedSha256) {
        throw "FFmpegKit full checksum mismatch. Expected $expectedSha256, got $actualHash."
    }

    Move-Item -LiteralPath $temporaryPath -Destination $targetPath -Force

    Write-Host "Android FFmpegKit full $version downloaded and verified."
    Write-Host "Path: $targetPath"
    Write-Host "SHA-256: $actualHash"
}

foreach ($supportingArtifact in $supportingArtifacts) {
    $supportingTarget = Join-Path $OutputDirectory $supportingArtifact.Name
    $supportingTemporary = Join-Path $OutputDirectory "$($supportingArtifact.Name).download"

    if ((Test-Path -LiteralPath $supportingTarget) -and -not $Force) {
        $existingHash = (Get-FileHash -LiteralPath $supportingTarget -Algorithm SHA256).Hash
        if ($existingHash -ieq $supportingArtifact.Sha256) {
            Write-Host "Android FFmpegKit support artifact is already available and verified: $($supportingArtifact.Name)"
            continue
        }

        throw "Existing support artifact checksum does not match the pinned artifact: $supportingTarget"
    }

    if (Test-Path -LiteralPath $supportingTemporary) {
        Remove-Item -LiteralPath $supportingTemporary -Force
    }

    Write-Host "Downloading Android FFmpegKit support artifact $($supportingArtifact.Name)..."
    & curl.exe -L --fail --retry 5 --retry-delay 2 --output $supportingTemporary $supportingArtifact.Url
    if ($LASTEXITCODE -ne 0) {
        throw "FFmpegKit support artifact download failed with exit code $LASTEXITCODE."
    }

    $actualHash = (Get-FileHash -LiteralPath $supportingTemporary -Algorithm SHA256).Hash
    if ($actualHash -ine $supportingArtifact.Sha256) {
        throw "FFmpegKit support artifact checksum mismatch for $($supportingArtifact.Name). Expected $($supportingArtifact.Sha256), got $actualHash."
    }

    Move-Item -LiteralPath $supportingTemporary -Destination $supportingTarget -Force
    Write-Host "Path: $supportingTarget"
    Write-Host "SHA-256: $actualHash"
}
