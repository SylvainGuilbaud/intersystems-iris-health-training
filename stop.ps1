# Stop script for iris-training
# This script is used to stop the IRIS containers.

Write-Host "Stopping the containers..."
& docker compose down

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to stop the containers." -ForegroundColor Red
    exit 1
} else {
    Write-Host "Containers stopped successfully." -ForegroundColor Green
}
