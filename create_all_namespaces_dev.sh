#!/bin/bash

TARGET=${1:-dev-aws}

for name in QA-TESTING UAT STAGE
do
    ./create_namespace.sh $name $TARGET -y
    ./create_namespace.sh $name $TARGET -y
done    
