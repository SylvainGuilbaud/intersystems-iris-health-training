# Launch Angular Web App
# This script navigates to the Angular project directory, installs dependencies if needed, and starts the dev server.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$angularDir = Join-Path $scriptDir "iris" "angular"

Write-Host "Navigating to $angularDir"
Set-Location $angularDir

# Install dependencies on first run (node_modules is git-ignored)
if (-Not (Test-Path "node_modules")) {
    Write-Host "Installing Angular dependencies (first run)..."
    & npm install
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to install dependencies." -ForegroundColor Red
        exit 1
    }
}

Write-Host "Starting Angular development server..."
& npx ng serve
