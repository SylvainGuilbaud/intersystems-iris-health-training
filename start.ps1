# Start script for iris-training
# This script is used to start the IRIS container and ensure that the correct permissions are set on the persistent volumes.

# Load environment variables from .env file
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^\s*([^=]+)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            [System.Environment]::SetEnvironmentVariable($name, $value)
        }
    }
} else {
    Write-Host "ERROR: .env file not found" -ForegroundColor Red
    exit 1
}

# Set permissions on the persistent volumes
Write-Host "Setting permissions on persistent volumes..."
& ".\create_volumes_with_permissions.ps1"

# Start the containers
Write-Host "Starting the containers..."
& docker compose -p "$($env:IRIS_INSTANCE_NAME)" up -d

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to start the containers." -ForegroundColor Red
    exit 1
} else {
    Write-Host "Containers started successfully." -ForegroundColor Green
}
