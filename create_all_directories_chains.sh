#!/bin/bash

for name in Delphine Danmark Marck-Augustus Carl-Jamie Francois Rochelle Neil Adrian Philippe Jean-Michel Olivier Michael Sophie Frederic
do
    ./create_directories_chains.sh "$name" aws -y
done    
