param(
    [string]$Godot = 'C:/Users/49175/Downloads/Godot_v4.7.2-stable_win64.exe',
    [switch]$Visual
)
$ErrorActionPreference = 'Stop'
$projectDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$env:APPDATA = Join-Path $projectDir '.test-runtime/roaming'
$env:LOCALAPPDATA = Join-Path $projectDir '.test-runtime/local'
New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
function Run-Godot([string]$Scene, [string]$Log, [string]$Extra, [bool]$WaitForExit = $true) {
    $display = if ($Visual -and $Scene -in @('smoke','inventory','delivery','sale_stock')) { '' } else { '--headless' }
    $arguments = "$display --path `"$projectDir`" --log-file `"$PSScriptRoot/$Log.log`" res://tests/$Scene.tscn $Extra"
    $process = Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden -PassThru
    if ($WaitForExit) {
        if (-not $process.WaitForExit(45000)) { throw "Timed out: $Scene $Extra" }
    }
    return $process
}
    $extra = if ($Visual) { '-- --visual' } else { '' }
    $sale = Run-Godot 'sale_stock' 'sale_stock' $extra
    Get-Content "$PSScriptRoot/sale_stock.log"
    if (-not (Select-String -Path "$PSScriptRoot/sale_stock.log" -SimpleMatch 'SALE_STOCK RESULT: 0 failure(s)')) { throw 'Sale stock tests failed' }
    $delivery = Run-Godot 'delivery' 'delivery' $extra
    Get-Content "$PSScriptRoot/delivery.log"
    if (-not (Select-String -Path "$PSScriptRoot/delivery.log" -SimpleMatch 'DELIVERY RESULT: 0 failure(s)')) { throw 'Delivery tests failed' }
    $inventory = Run-Godot 'inventory' 'inventory' $extra
    Get-Content "$PSScriptRoot/inventory.log"
    if (-not (Select-String -Path "$PSScriptRoot/inventory.log" -SimpleMatch 'INVENTORY RESULT: 0 failure(s)')) { throw 'Inventory tests failed' }
    $smoke = Run-Godot 'smoke' 'smoke' $extra
    Get-Content "$PSScriptRoot/smoke.log"
    if (-not (Select-String -Path "$PSScriptRoot/smoke.log" -SimpleMatch 'SMOKE RESULT: 0 failure(s)')) { throw 'Smoke tests failed' }
# Historical LAN tests are retained but disabled with multiplayer.
foreach ($scene in @('inventory','smoke','delivery','sale_stock')) {
    if (Select-String -Path "$PSScriptRoot/$scene.log" -Pattern 'SCRIPT ERROR:|FAIL:') { throw "$scene reported a script error" }
}
Write-Output 'ALL SINGLE-PLAYER TESTS PASSED'
