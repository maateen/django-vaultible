# !/bin/bash

if [ "$RoleID" = "" -a "$SecretID" = "" ]; then
    echo 'Please, set RoleID and SecretID as environment variable.'
else
    approle_output=`vault write auth/approle/login role_id=${RoleID} secret_id=${SecretID}`
    token=`echo $approle_output | awk '{print $6}'`
    auth_token=`vault auth ${token}`
    database_output=`vault read database/creds/admin`
    username=`echo $database_output | awk '{print $14}'`
    password=`echo $database_output | awk '{print $12}'`
    echo "Hello `whoami`, Your database credential is as follows:"
    echo 'Username:' $username
    echo 'Password:' $password
fi