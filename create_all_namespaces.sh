#!/bin/bash

for name in Delphine Danmark Marck-Augustus Carl-Jamie Francois Rochelle Neil Adrian Philippe Jean-Michel Olivier Michael Sophie Frederic
do
    ./delete_namespace.sh $name dev-aws -y
    ./create_namespace.sh $name dev-aws -y
    ./delete_namespace.sh $name prod-aws -y
    ./create_namespace.sh $name prod-aws -y
done    
