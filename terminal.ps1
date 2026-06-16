param(
    [string]$Namespace = "TRAINING",
    [string]$Target = "dev-aws"
)

# Load cloud environment variables
$ACCESS_KEY_FILENAME = "./iris/key/IRIS-Health-TRAINING.pem"
$PUBLIC_DNS = "ec2-63-177-72-122.eu-central-1.compute.amazonaws.com"
$CLOUD_USERNAME = "ubuntu"

switch ($Target) {
    "dev-aws"  { $CONTAINER = "iris-health-training-dev" }
    "prod-aws" { $CONTAINER = "iris-health-training" }
    "dev"      { $CONTAINER = "iris-health-training-dev" }
    "prod"     { $CONTAINER = "iris-health-training" }
    default {
        Write-Host "Usage: .\iris_session.ps1 [training|user|%sys|<your_namespace>] [dev-aws|prod-aws|dev|prod]"
        exit 1
    }
}

if ($Target -like "*aws*") {
    ssh -t -i $ACCESS_KEY_FILENAME "${CLOUD_USERNAME}@${PUBLIC_DNS}" "docker exec -ti $CONTAINER iris session iris -U $Namespace"
} else {
    docker exec -ti $CONTAINER iris session iris -U $Namespace
}
