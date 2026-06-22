# Launch DGLAB Desktop Client
# This script navigates to the Python directory and runs the DGLAB Tkinter application.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pythonDir = Join-Path $scriptDir "iris" "python"

Write-Host "Navigating to $pythonDir"
Set-Location $pythonDir

Write-Host "Starting DGLAB desktop client..."
& python DGLAB.py

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: DGLAB client exited with error code $LASTEXITCODE" -ForegroundColor Red
    exit 1
}
