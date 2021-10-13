# Argument $1: $(cognitoPoolId)
# Argument $2: $(userEmail)
# Argument $3: $(SendCode)
echo "##[command] $0"

if [ -z $COGNITOPOOLID ] ; then
    echo "##[error] cognitoPoolId not provided."
    exit 1
elif [ -z $USEREMAIL ] ; then
    echo "##[error] userEmail not provided."
    exit 1
fi

cognitoUsers=`aws cognito-idp admin-get-user --user-pool-id $COGNITOPOOLID  --username $USEREMAIL --query "Username" --output text`
if [ -z $cognitoUsers ] ; then
    echo "##[error] no cognito user found in pool matching email."
    exit 1
fi

for cognitoUser in $cognitoUsers; do
    echo "##[debug] Confirm cognito user: $cognitoUser Set $FIELD to $VALUE"
    aws cognito-idp admin-confirm-sign-up --user-pool-id $COGNITOPOOLID --username $cognitoUser  
    aws cognito-idp admin-get-user --user-pool-id $COGNITOPOOLID  --username $cognitoUser
done