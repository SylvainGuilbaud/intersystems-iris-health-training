param(
    [Parameter(Mandatory=$true)]
    [string]$Namespace,
    [string]$Target = "dev-aws"
)

# Load cloud environment variables
$ACCESS_KEY_FILENAME = "./iris/key/IRIS-Health-TRAINING.pem"
$PUBLIC_DNS = "ec2-63-177-72-122.eu-central-1.compute.amazonaws.com"
$CLOUD_USERNAME = "ubuntu"
$ISC_DATA_DIRECTORY = "databases"

# Convert namespace to uppercase/lowercase variants
$Namespace     = $Namespace.ToUpper()
$NamespaceApp  = $Namespace.ToLower()

$Timestamp = Get-Date -Format "yyyyMMddHHmmss"
$CPF_FILE  = "delete_namespace_merge_${Namespace}_${Timestamp}.cpf"
$REMOTE_TMP = "/tmp/$CPF_FILE"

switch ($Target) {
    "dev-aws"  { $CONTAINER = "iris-health-training-dev" }
    "prod-aws" { $CONTAINER = "iris-health-training" }
    "dev"      { $CONTAINER = "iris-health-training-dev" }
    "prod"     { $CONTAINER = "iris-health-training" }
    default {
        Write-Host "Usage: .\delete_namespace.ps1 <Namespace> [dev-aws|prod-aws|dev|prod]"
        exit 1
    }
}

# Generate CPF file dynamically from namespace name
@"
[Actions]
DeleteDatabase:Name=${Namespace}_DATA,Directory=/${ISC_DATA_DIRECTORY}/mgr/${Namespace}_DATA
DeleteDatabase:Name=${Namespace}_CODE,Directory=/${ISC_DATA_DIRECTORY}/mgr/${Namespace}_CODE
DeleteNamespace:Name=${Namespace}
DeleteResource:Name=%DB_${Namespace}_DATA
DeleteResource:Name=%DB_${Namespace}_CODE
DeleteApplication:Name=/csp/healthshare/${NamespaceApp}
DeleteApplication:Name=/csp/healthshare/${NamespaceApp}/bulkfhir
DeleteApplication:Name=/csp/healthshare/${NamespaceApp}/bulkfhir/api
DeleteApplication:Name=/csp/healthshare/${NamespaceApp}/services
DeleteRole:Name=${NAMESPACE}_ROLE
DeleteUser:Name=${NAMESPACE}
"@ | Set-Content -Encoding UTF8 -NoNewline $CPF_FILE

Write-Host "Generated $CPF_FILE for namespace $Namespace"
Write-Host ""
Write-Host "About to delete namespace '$Namespace' on container '$CONTAINER' (target: $Target)"
$confirm = Read-Host "Are you sure? [y/N]"
if ($confirm -notmatch '^[yY]$') {
    Write-Host "Aborted."
    Remove-Item -Force $CPF_FILE -ErrorAction SilentlyContinue
    exit 0
}

function Invoke-Step {
    param([string]$Description, [scriptblock]$Command)
    & $Command
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: $Description failed. Aborting."
        Remove-Item -Force $CPF_FILE -ErrorAction SilentlyContinue
        exit 1
    }
    Write-Host "OK: $Description"
}

if ($Target -like "*aws*") {
    Write-Host "Copying $CPF_FILE to ${CLOUD_USERNAME}@${PUBLIC_DNS}:$REMOTE_TMP ..."
    Invoke-Step "scp $CPF_FILE to remote host" {
        scp -i $ACCESS_KEY_FILENAME $CPF_FILE "${CLOUD_USERNAME}@${PUBLIC_DNS}:$REMOTE_TMP"
    }

    Write-Host "Copying $CPF_FILE into container $CONTAINER ..."
    Invoke-Step "docker cp into container" {
        ssh -i $ACCESS_KEY_FILENAME "${CLOUD_USERNAME}@${PUBLIC_DNS}" "docker cp $REMOTE_TMP ${CONTAINER}:${REMOTE_TMP}"
    }

    Write-Host "Running iris merge on $CONTAINER ..."
    Invoke-Step "iris merge" {
        ssh -i $ACCESS_KEY_FILENAME "${CLOUD_USERNAME}@${PUBLIC_DNS}" "docker exec $CONTAINER iris merge iris $REMOTE_TMP"
    }
} else {
    Write-Host "Copying $CPF_FILE into container $CONTAINER ..."
    Invoke-Step "docker cp into container" {
        docker cp $CPF_FILE "${CONTAINER}:${REMOTE_TMP}"
    }

    Write-Host "Running iris merge on $CONTAINER ..."
    Invoke-Step "iris merge" {
        docker exec $CONTAINER iris merge iris $REMOTE_TMP
    }
}

Remove-Item -Force $CPF_FILE -ErrorAction SilentlyContinue

# Verify the namespace no longer exists in the target IRIS instance
Write-Host "Verifying namespace '$Namespace' no longer exists in IRIS ..."
Write-Host "Running check_namespace.ps1 -Namespace $Namespace -Target $Target ..."
Write-Host "this should fail with an error message indicating the namespace does not exist."
& "$PSScriptRoot/check_namespace.ps1" -Namespace $Namespace -Target $Target
if ($LASTEXITCODE -eq 0) {
    Write-Host "WARNING: Namespace '$Namespace' still exists in IRIS after deletion."
    exit 1
} else {
    Write-Host "SUCCESS: Namespace '$Namespace' has been deleted from IRIS."
}

Write-Host "Done."
