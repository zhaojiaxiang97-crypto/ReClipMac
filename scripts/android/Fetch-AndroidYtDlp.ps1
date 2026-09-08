[CmdletBinding()]
param(
    [string] $OutputDirectory = "",
    [switch] $Force
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot ".artifacts\android-runtime\yt-dlp-android-2.0.2"
}

$version = "2.0.2"
$artifactName = "yt-dlp-android-$version.aar"
$expectedSha256 = "D2E71858F4C144F021534E658B94D0C3616818B662C848903F1F2FE9DEC4A7D0"
$sourceUrl = "https://repo1.maven.org/maven2/dev/ffmpegkit-maintained/yt-dlp-android/$version/$artifactName"
$targetPath = Join-Path $OutputDirectory $artifactName
$temporaryPath = Join-Path $OutputDirectory "$artifactName.download"

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

if ((Test-Path -LiteralPath $targetPath) -and -not $Force) {
    $existingHash = (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash
    if ($existingHash -ieq $expectedSha256) {
        Write-Host "Android yt-dlp $version is already available and verified."
        Write-Host "Path: $targetPath"
        Write-Host "SHA-256: $existingHash"
        exit 0
    }

    throw "Existing yt-dlp AAR checksum does not match the pinned source: $targetPath"
}

if (Test-Path -LiteralPath $temporaryPath) {
    Remove-Item -LiteralPath $temporaryPath -Force
}

Write-Host "Downloading Android yt-dlp $version from Maven Central..."
& curl.exe -L --fail --retry 5 --retry-delay 2 --output $temporaryPath $sourceUrl
if ($LASTEXITCODE -ne 0) {
    throw "yt-dlp AAR download failed with exit code $LASTEXITCODE."
}

$actualHash = (Get-FileHash -LiteralPath $temporaryPath -Algorithm SHA256).Hash
if ($actualHash -ine $expectedSha256) {
    throw "yt-dlp AAR checksum mismatch. Expected $expectedSha256, got $actualHash."
}

Move-Item -LiteralPath $temporaryPath -Destination $targetPath -Force

Write-Host "Android yt-dlp $version downloaded."
Write-Host "Path: $targetPath"
Write-Host "SHA-256: $actualHash"
