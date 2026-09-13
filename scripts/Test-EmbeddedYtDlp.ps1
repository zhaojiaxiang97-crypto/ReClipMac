[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $Executable,
    [Parameter(Mandatory = $true)][string] $QtBin,
    [Parameter(Mandatory = $true)][string] $EvidenceDirectory,
    [switch] $SkipProcessTrace
)

$ErrorActionPreference = 'Stop'
$Executable = (Resolve-Path -LiteralPath $Executable).Path
$QtBin = (Resolve-Path -LiteralPath $QtBin).Path
$EvidenceDirectory = [IO.Path]::GetFullPath($EvidenceDirectory)
New-Item -ItemType Directory -Force -Path $EvidenceDirectory | Out-Null
$stdoutPath = Join-Path $EvidenceDirectory 'embedded-test.stdout.log'
$stderrPath = Join-Path $EvidenceDirectory 'embedded-test.stderr.log'
$sourceId = 'ReClipProcessTrace-' + [Guid]::NewGuid().ToString('N')
$savedPath = $env:PATH
$savedPythonHome = $env:PYTHONHOME
$savedPythonPath = $env:PYTHONPATH
$subscription = $null
try {
    # Use process creation events, not periodic snapshots which miss short jobs.
    if (-not $SkipProcessTrace) {
        $subscription = Register-WmiEvent -Query 'SELECT * FROM Win32_ProcessStartTrace' -SourceIdentifier $sourceId
    }
    $env:PATH = "$QtBin;$env:SystemRoot\System32;$env:SystemRoot"
    $env:PYTHONHOME = 'Z:\reclip-must-not-import-system-python'
    $env:PYTHONPATH = 'Z:\reclip-must-not-import-user-modules'
    $testProcess = Start-Process -FilePath $Executable -WorkingDirectory (Split-Path $Executable -Parent) -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    $testHandle = $testProcess.Handle
    if (-not $testProcess.WaitForExit(60000)) {
        Stop-Process -Id $testProcess.Id
        throw 'The test helper exceeded 60 seconds and was stopped.'
    }
    Start-Sleep -Milliseconds 300
    $events = @(if ($subscription) { Get-Event -SourceIdentifier $sourceId -ErrorAction SilentlyContinue | ForEach-Object {
        $entry = $_.SourceEventArgs.NewEvent
        [pscustomobject]@{ processId = [int]$entry.ProcessID; parentId = [int]$entry.ParentProcessID; name = [string]$entry.ProcessName }
    } })
    $children = @($events | Where-Object { $_.parentId -eq $testProcess.Id })
    $record = [ordered]@{
        executable = $Executable
        executableSha256 = (Get-FileHash -LiteralPath $Executable -Algorithm SHA256).Hash
        testPid = $testProcess.Id
        exitCode = $testProcess.ExitCode
        processCreationTraceAvailable = -not $SkipProcessTrace
        observedDirectChildren = $children
        childCount = if ($SkipProcessTrace) { $null } else { $children.Count }
        testedAt = (Get-Date).ToUniversalTime().ToString('o')
    }
    $record | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $EvidenceDirectory 'process-trace.json') -Encoding UTF8
    Get-Content -LiteralPath $stdoutPath -Encoding UTF8
    Get-Content -LiteralPath $stderrPath -Encoding UTF8
    if ($testProcess.ExitCode -ne 0 -or $children.Count -ne 0) {
        throw "Embedded verification failed: exit=$($testProcess.ExitCode), children=$($children.Count)"
    }
    if ($SkipProcessTrace) {
        Write-Host "PASS: functional tests only; OS process trace was NOT performed. Evidence: $EvidenceDirectory"
    } else {
        Write-Host "PASS: test process $($testProcess.Id), no child-process creation events. Evidence: $EvidenceDirectory"
    }
} finally {
    if ($subscription) {
        Unregister-Event -SourceIdentifier $sourceId
        Get-Event -SourceIdentifier $sourceId -ErrorAction SilentlyContinue | Remove-Event
        Remove-Job -Id $subscription.Id -Force
    }
    $env:PATH = $savedPath
    $env:PYTHONHOME = $savedPythonHome
    $env:PYTHONPATH = $savedPythonPath
}
