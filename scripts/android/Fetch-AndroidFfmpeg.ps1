[CmdletBinding()]
param(
    [string] $OutputDirectory = "",
    [switch] $Force
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot ".artifacts\android-runtime\ffmpeg-9.0"
}

$version = "9.0"
$sourceCommit = "90231cc0105aef4f76926b911535f5eb73511b86"
$expectedSha256 = "9085507B0DC32643B4D6D084A7E7D3469EF17907A7BA15C22D3997ED09C932AA"
$sourceUrl = "https://raw.githubusercontent.com/hzw1199/Android-FFmpeg-Prebuilt/$sourceCommit/ffmpeg-9.0/bin/ffmpeg"
$targetPath = Join-Path $OutputDirectory "ffmpeg"
$temporaryPath = Join-Path $OutputDirectory "ffmpeg.download"

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

if ((Test-Path -LiteralPath $targetPath) -and -not $Force) {
    $existingHash = (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash
    if ($existingHash -ieq $expectedSha256) {
        Write-Host "Android FFmpeg $version is already available and verified."
        Write-Host "Path: $targetPath"
        Write-Host "SHA-256: $existingHash"
        exit 0
    }

    throw "Existing FFmpeg checksum does not match the pinned source: $targetPath"
}

if (Test-Path -LiteralPath $temporaryPath) {
    Remove-Item -LiteralPath $temporaryPath -Force
}

Write-Host "Downloading Android FFmpeg $version from commit $sourceCommit..."
& curl.exe -L --fail --retry 5 --retry-delay 2 --output $temporaryPath $sourceUrl
if ($LASTEXITCODE -ne 0) {
    throw "FFmpeg download failed with exit code $LASTEXITCODE."
}

$actualHash = (Get-FileHash -LiteralPath $temporaryPath -Algorithm SHA256).Hash
if ($actualHash -ine $expectedSha256) {
    throw "FFmpeg checksum mismatch. Expected $expectedSha256, got $actualHash."
}

Move-Item -LiteralPath $temporaryPath -Destination $targetPath -Force

Write-Host "Android FFmpeg $version downloaded and verified."
Write-Host "Path: $targetPath"
Write-Host "SHA-256: $actualHash"
