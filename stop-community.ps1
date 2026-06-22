# Stop script for iris-training community
# This script is used to stop the IRIS community containers.

Write-Host "Stopping the community containers..."
& docker compose -f docker-compose-community.yml down

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to stop the community containers." -ForegroundColor Red
    exit 1
} else {
    Write-Host "Community containers stopped successfully." -ForegroundColor Green
}
