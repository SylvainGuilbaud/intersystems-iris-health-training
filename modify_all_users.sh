#!/bin/bash

for name in Delphine Danmark Marck-Augustus Carl-Jamie Francois Rochelle Neil Adrian Philippe Jean-Michel Olivier Michael Sophie
do
    ./modify_user.sh $name dev-aws -y
    ./modify_user.sh $name prod-aws -y
done    
