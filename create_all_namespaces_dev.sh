#!/bin/bash

for name in QA-TESTING UAT STAGE
do
    ./delete_namespace.sh $name dev-aws -y
    ./create_namespace.sh $name dev-aws -y
done    
