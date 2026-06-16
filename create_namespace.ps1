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

# Convert namespace to uppercase
$Namespace = $Namespace.ToUpper()

$Timestamp = Get-Date -Format "yyyyMMddHHmmss"
$CPF_FILE = "create_namespace_merge_${Namespace}_${Timestamp}.cpf"
$REMOTE_TMP = "/tmp/$CPF_FILE"

switch ($Target) {
    "dev-aws"  { $CONTAINER = "iris-health-training-dev" }
    "prod-aws" { $CONTAINER = "iris-health-training" }
    "dev"      { $CONTAINER = "iris-health-training-dev" }
    "prod"     { $CONTAINER = "iris-health-training" }
    default {
        Write-Host "Usage: .\create_namespace.ps1 <Namespace> [dev-aws|prod-aws|dev|prod]"
        exit 1
    }
}

# Generate CPF file dynamically from namespace name
@"
[Actions]
CreateResource:Name=%DB_${Namespace}_DATA,Description="${Namespace}_DATA database"
CreateDatabase:Name=${Namespace}_DATA,Directory=/${ISC_DATA_DIRECTORY}/mgr/${Namespace}_DATA,Resource=%DB_${Namespace}_DATA
CreateResource:Name=%DB_${Namespace}_CODE,Description="${Namespace}_CODE database"
CreateDatabase:Name=${Namespace}_CODE,Directory=/${ISC_DATA_DIRECTORY}/mgr/${Namespace}_CODE,Resource=%DB_${Namespace}_CODE
CreateNamespace:Name=${Namespace},Globals=${Namespace}_DATA,Routines=${Namespace}_CODE,Interop=1
CreateRole:Name=${NAMESPACE}_ROLE,Description="Role for ${NAMESPACE} namespace",Resources=%DB_${NAMESPACE}_DATA,%DB_${NAMESPACE}_CODE
CreateUser:Name=${NAMESPACE},NameSpace=${NAMESPACE},AccountNeverExpires=1,PasswordNeverExpires=1,Roles=%All,${NAMESPACE}_ROLE,PasswordHash=4c458bac977abcc5c5537edca92bd3789eab4c8bc3af70874966c35a0947f0d358591e85f176d2c6d06b7e41ba439cdd91f0b6f42c541f906656852d1e4456a1,b0da7a46afc5af0d44da87452b85e5cefb9fe02aa01706cf501f1a168babaab78fef063c5a577e8228d6fcc0f3961363c9906d39cc689e5a264c447a0fff3692,10000,SHA512
"@ | Set-Content -Encoding UTF8 -NoNewline $CPF_FILE

Write-Host "Generated $CPF_FILE for namespace $Namespace"
Write-Host ""
Write-Host "About to create namespace '$Namespace' on container '$CONTAINER' (target: $Target)"
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

# Verify the namespace exists in the target IRIS instance
Write-Host "Verifying namespace '$Namespace' exists in IRIS ..."
Write-Host "Running check_namespace.ps1 -Namespace $Namespace -Target $Target ..."
Write-Host "this should succeed with a message indicating the namespace exists."
& "$PSScriptRoot/check_namespace.ps1" -Namespace $Namespace -Target $Target
if ($LASTEXITCODE -ne 0) {
    Write-Host "WARNING: Namespace '$Namespace' does not exist in IRIS after creation."
    exit 1
} else {
    Write-Host "SUCCESS: Namespace '$Namespace' has been created in IRIS."
}
Write-Host "Done."
