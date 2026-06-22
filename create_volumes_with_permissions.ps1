# This script is used to set the correct permissions on the persistent volume 
# in order to allow the IRIS container to read and write to it without issues.

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

$volumePrefix = if ($args.Count -gt 0) { $args[0] } else { $env:IRIS_INSTANCE_NAME }

Write-Host "Setting permissions on persistent volumes for instance: $volumePrefix"

function Set-VolumePermissions {
    param([string]$suffix)
    
    $volumeName = "${volumePrefix}_$suffix"
    $mountPoint = "/$suffix"
    
    Write-Host "Setting permissions for volume: $volumeName"
    
    & docker run --rm -v "${volumeName}:${mountPoint}" alpine sh -c `
        "chown -R 51773:51773 ${mountPoint} && chmod -R u+rwX,g+rwX ${mountPoint}"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to set permissions for $volumeName" -ForegroundColor Red
        exit 1
    }
}

# Set permissions for the persistent volumes
Set-VolumePermissions "dev_databases"
Set-VolumePermissions "dev_journal"
Set-VolumePermissions "dev_journal2"
Set-VolumePermissions "dev_WIJ"
Set-VolumePermissions "prod_databases"
Set-VolumePermissions "prod_journal"
Set-VolumePermissions "prod_journal2"
Set-VolumePermissions "prod_WIJ"

Write-Host "Permissions set successfully." -ForegroundColor Green
