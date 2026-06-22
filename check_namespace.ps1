param(
    [Parameter(Mandatory=$true)]
    [string]$Namespace,
    [string]$Target = "dev-aws"
)

$ErrorActionPreference = "Stop"

# Load cloud environment variables
$ACCESS_KEY_FILENAME = "./iris/key/IRIS-Health-TRAINING.pem"
$PUBLIC_DNS = "ec2-63-177-72-122.eu-central-1.compute.amazonaws.com"
$CLOUD_USERNAME = "ubuntu"

# Convert namespace to uppercase
$Namespace = $Namespace.ToUpper()

switch ($Target) {
    "dev-aws"  { $CONTAINER = "iris-health-training-dev" }
    "prod-aws" { $CONTAINER = "iris-health-training-prod" }
    "dev"      { $CONTAINER = "iris-health-training-dev" }
    "prod"     { $CONTAINER = "iris-health-training-prod" }
    "dev-community" { $CONTAINER = "iris-health-training-dev-community" }
    "prod-community" { $CONTAINER = "iris-health-training-prod-community" }
    default {
        Write-Host "Usage: .\check_namespace.ps1 <Namespace> [dev-aws|prod-aws|dev|prod|dev-community|prod-community]"
        exit 1
    }
}

# Verify the namespace exists in the target IRIS instance
Write-Host "Verifying namespace '$Namespace' exists in IRIS ..."

$irisScript = @"
Write "NS_EXISTS=",##class(Config.Namespaces).Exists("$Namespace"),!
halt
"@

if ($Target -like "*aws*") {
    $RESULT = ($irisScript | ssh -i $ACCESS_KEY_FILENAME "${CLOUD_USERNAME}@${PUBLIC_DNS}" "docker exec -i $CONTAINER iris session iris -U %SYS" 2>&1) | Out-String
} else {
    $RESULT = ($irisScript | docker exec -i $CONTAINER iris session iris -U %SYS 2>&1) | Out-String
}

$match = [regex]::Match($RESULT, 'NS_EXISTS=([01])')
$exists = if ($match.Success) { $match.Groups[1].Value } else { "" }

if ($exists -eq '1') {
    Write-Host "SUCCESS: Namespace '$Namespace' exists in IRIS on container '$CONTAINER' (target: $Target)."
} else {
    Write-Host "ERROR: Namespace '$Namespace' does not exist in IRIS on container '$CONTAINER' (target: $Target)."
    if (-not $match.Success) {
        Write-Host "Details: unable to parse NS_EXISTS marker from IRIS output."
        Write-Host $RESULT
    }
    exit 1
}

Write-Host "Done."
