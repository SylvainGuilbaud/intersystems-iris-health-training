param(
    [Parameter(Mandatory=$true)]
    [string]$Namespace,
    [string]$Target = "dev-aws"
)

# Load cloud environment variables
$ACCESS_KEY_FILENAME = "./iris/key/IRIS-Health-TRAINING.pem"
$PUBLIC_DNS = "ec2-63-177-72-122.eu-central-1.compute.amazonaws.com"
$CLOUD_USERNAME = "ubuntu"

# Convert namespace to uppercase
$Namespace = $Namespace.ToUpper()

switch ($Target) {
    "dev-aws"  { $CONTAINER = "iris-health-training-dev" }
    "prod-aws" { $CONTAINER = "iris-health-training" }
    "dev"      { $CONTAINER = "iris-health-training-dev" }
    "prod"     { $CONTAINER = "iris-health-training" }
    default {
        Write-Host "Usage: .\check_namespace.ps1 <Namespace> [dev-aws|prod-aws|dev|prod]"
        exit 1
    }
}

# Verify the namespace exists in the target IRIS instance
Write-Host "Verifying namespace '$Namespace' exists in IRIS ..."
$VERIFY_CMD = "docker exec -i $CONTAINER iris session iris -U %SYS <<'IRISSESSION'`nWrite ##class(Config.Namespaces).Exists(`"$Namespace`")`nhalt`nIRISSESSION"

if ($Target -like "*aws*") {
    $RESULT = (ssh -i $ACCESS_KEY_FILENAME "${CLOUD_USERNAME}@${PUBLIC_DNS}" $VERIFY_CMD) -replace '\s', ''
} else {
    $RESULT = (Invoke-Expression $VERIFY_CMD) -replace '\s', ''
}

if ($RESULT -match '1') {
    Write-Host "SUCCESS: Namespace '$Namespace' exists in IRIS on container '$CONTAINER' (target: $Target)."
} else {
    Write-Host "ERROR: Namespace '$Namespace' does not exist in IRIS on container '$CONTAINER' (target: $Target) (result: '$RESULT')."
    exit 1
}

Write-Host "Done."
