# if only one argument, copy to home directory
# if two arguments, copy to second argument directory
if [ "$#" -eq 1 ]; then
    set -- "$1" "$1"
fi
scp -r -i $ACCESS_KEY_FILENAME $1 $CLOUD_USERNAME@$PUBLIC_DNS:$2
