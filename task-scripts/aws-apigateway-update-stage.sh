# Argument $1: api-id
# Argument $2: get-stage-name
# Argument $3: set-stage-name
# Returns 0: update api successful
# Returns 1: update api unsuccessful

echo "##[command] $0"

if [ -z $1 ]; then
    echo "##[error] Update API Gateway: Argument [api-id] not provided."
    exit 1
elif [ -z $2 ]; then
    echo "##[error] Update API Gateway: Argument [get-stage-name] not provided."
    exit 1
elif [ -z $3 ]; then
    echo "##[error] Update API Gateway: Argument [set-stage-name] not provided."
    exit 1
fi

getStage="${2,^^}"
setStage="${3,^^}"

apiName=`aws apigateway get-rest-api --rest-api-id $1 --query "name" --output text`
fromDeploymentId=`aws apigateway get-stage --rest-api-id $1 --stage-name "$setStage" --query "deploymentId" --output text`
toDeploymentId=`aws apigateway get-stage --rest-api-id $1 --stage-name "$getStage" --query "deploymentId" --output text`

if [ -z $fromDeploymentId ]; then
    echo "##[error] Update API Gateway: [deploymentId] not found for get-stage-name [$getStage]."
    exit 1
elif [ $fromDeploymentId == $toDeploymentId ] ; then
    echo "##[info] Update API Gateway: $apiName Stage: /$setStage already deployed to: $fromDeploymentId"
    exit 0
fi

echo "##[command] Update API Gateway: $apiName Stage: /$setStage deployment from: $fromDeploymentId to: $toDeploymentId"
verifyDeploymentId=`aws apigateway update-stage --rest-api-id $1 --stage-name $setStage --patch-operations op=replace,path=/deploymentId,value=$toDeploymentId --query "deploymentId" --output text`

if [ "$verifyDeploymentId" == "$toDeploymentId" ] ; then
    echo "##[info] Update API Gateway: $apiName/$setStage update deployment to: $verifyDeploymentId successful."
    exit 0
else
    echo "##[error] Update API Gateway: $apiName/$setStage update deployment to: $toDeploymentId unsuccessful."
    exit 1
fi
