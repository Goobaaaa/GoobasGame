param(
    [string]$Godot = 'C:/Users/backh/Desktop/Codex/Godot/Godot_v4.7.2-stable_win64.exe',
    [switch]$Visual,
    [switch]$LanOnly
)
$ErrorActionPreference = 'Stop'
$projectDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$env:APPDATA = Join-Path $projectDir '.test-runtime/roaming'
$env:LOCALAPPDATA = Join-Path $projectDir '.test-runtime/local'
New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
function Run-Godot([string]$Scene, [string]$Log, [string]$Extra, [bool]$WaitForExit = $true) {
    $display = if ($Visual -and $Scene -eq 'smoke') { '' } else { '--headless' }
    $arguments = "$display --path `"$projectDir`" --log-file `"$PSScriptRoot/$Log.log`" res://tests/$Scene.tscn $Extra"
    $process = Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden -PassThru
    if ($WaitForExit) {
        if (-not $process.WaitForExit(45000)) { throw "Timed out: $Scene $Extra" }
    }
    return $process
}
if (-not $LanOnly) {
    $extra = if ($Visual) { '-- --visual' } else { '' }
    $smoke = Run-Godot 'smoke' 'smoke' $extra
    Get-Content "$PSScriptRoot/smoke.log"
    if (-not (Select-String -Path "$PSScriptRoot/smoke.log" -SimpleMatch 'SMOKE RESULT: 0 failure(s)')) { throw 'Smoke tests failed' }
}
$server = Run-Godot 'lan' 'lan-host' '-- --host' $false
# Wait for startup only; networking tests use separate real OS processes.
Start-Sleep -Milliseconds 800
$client = Run-Godot 'lan' 'lan-client' ''
$late = Run-Godot 'lan' 'lan-late' '-- --late'
if (-not $server.WaitForExit(25000)) { throw 'LAN host timed out' }
foreach ($role in @('host','client','late')) {
    $logPath = "$PSScriptRoot/lan-$role.log"
    Get-Content $logPath
    if (-not (Select-String -Path $logPath -SimpleMatch "LAN RESULT [$role]: 0 failure(s)")) { throw "LAN $role failed" }
}
Write-Output 'ALL TESTS PASSED'
