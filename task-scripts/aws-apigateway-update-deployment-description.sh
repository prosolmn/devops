# Argument $1: api-id
# Argument $2: stage-name
# Argument $3: description
# Returns 0: update api successful
# Returns 1: update api unsuccessful

echo "##[command] $0"

if [ -z $1 ]; then
    echo "##[error] Arg [api-id] not provided."
    exit 1
elif [ -z $2 ]; then
    echo "##[error] Arg [stage-name] not provided."
    exit 1
elif [ -z $3 ]; then
    echo "##[error] Arg [version] not provided."
    exit 1
fi

stageName="${2^^}"

apiName=`aws apigateway get-rest-api --rest-api-id $1 --query "name" --output text`
deploymentId=`aws apigateway get-stage --rest-api-id $1 --stage-name "$stageName" --query "deploymentId" --output text`

if [ -z $deploymentId ]; then
    echo "##[error] [deploymentId] not found for stage-name [$stageName]."
    exit 1
fi

echo "##[command] update $apiName/$stageName ($deploymentId) description to: $3"
verifyDescription=`aws apigateway update-deployment --rest-api-id $1 --deployment-id $deploymentId --patch-operations op=replace,path=/description,value="$3" --query "description" --output text`

if [ "$verifyDescription" == "$3" ] ; then
    echo "##[info] update $apiName/$stageName ($deploymentId) description: successful."
    exit 0
else
    echo "##[error] update $apiName/$stageName ($deploymentId) description: unsuccessful."
    exit 1
fi
