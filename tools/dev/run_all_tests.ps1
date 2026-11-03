# Loop Town Demo - regression test runner
#
# Usage (from anywhere):
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/dev/run_all_tests.ps1
#
# Runs four checks in order. Exit code is 1 if any suite fails.
# NOTE: kept ASCII-only on purpose - Windows PowerShell 5.1 reads BOM-less
# UTF-8 files as ANSI, which corrupts non-ASCII literals.

$ErrorActionPreference = "Continue"

$Godot = "G:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

if (-not (Test-Path $Godot)) {
    Write-Error "Godot executable not found: $Godot"
    exit 1
}

$Suites = @(
    @{ Name = "script parse + class registration"; Script = "validate_project" },
    @{ Name = "asset library (definitions load + fields complete)"; Script = "validate_assets" },
    @{ Name = "map generation + player landing"; Script = "validate_runtime" },
    @{ Name = "core gameplay (move/jump/attack/hurt/death)"; Script = "validate_gameplay" },
    @{ Name = "map transition"; Script = "validate_transition" }
)

$Failed = 0
foreach ($Suite in $Suites) {
    Write-Host ""
    Write-Host ("=" * 60)
    Write-Host ("  " + $Suite.Name)
    Write-Host ("=" * 60)
    & $Godot --headless --path $ProjectRoot --script ("res://tools/dev/" + $Suite.Script + ".gd")
    if ($LASTEXITCODE -ne 0) {
        Write-Host ("  >>> FAILED: " + $Suite.Name)
        $Failed = 1
    }
}

Write-Host ""
if ($Failed -eq 1) {
    Write-Host "REGRESSION: FAILURES PRESENT"
    exit 1
}
Write-Host "REGRESSION: ALL PASSED"
exit 0
