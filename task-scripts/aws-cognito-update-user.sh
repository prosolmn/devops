# Argument $1: $(cognitoPoolId)
# Argument $2: $(userEmail)
# Argument $3: $(Field)
# Argument $4: $(Value) 
echo "##[command] $0"

if [ -z $COGNITOPOOLID ] ; then
    echo "##[error] cognitoPoolId not provided."
    exit 1
elif [ -z $USEREMAIL ] ; then
    echo "##[error] userEmail not provided."
    exit 1
elif [ -z $FIELD ] ; then
    echo "##[error] field not provided."
    exit 1
elif [ -z $VALUE ] ; then
    echo "##[error] value not provided."
    exit 1
fi

cognitoUsers=`aws cognito-idp admin-get-user --user-pool-id $COGNITOPOOLID  --username $USEREMAIL --query "Username" --output text`
if [ -z $cognitoUsers ] ; then
    echo "##[error] no cognito user found in pool matching email."
    exit 1
fi

for cognitoUser in $cognitoUsers; do
    echo "##[debug] Update cognito user: $cognitoUser Set $FIELD to $VALUE"

    if [[ "${FIELD,,}" == "enabled" ]] ; then
        if [[ "${VALUE,,}" == "true" ]] ; then
            aws cognito-idp admin-enable-user --user-pool-id $COGNITOPOOLID --username $cognitoUser
        else
            aws cognito-idp admin-disable-user --user-pool-id $COGNITOPOOLID --username $cognitoUser
        fi
    else
        aws cognito-idp admin-update-user-attributes --user-pool-id $COGNITOPOOLID --username $cognitoUser --user-attributes Name="$FIELD",Value="$VALUE"
    fi
  
    aws cognito-idp admin-get-user --user-pool-id $COGNITOPOOLID  --username $cognitoUser
done