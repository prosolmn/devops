# Argument $1: functionName=`echo "$lambdaArn" | rev | cut -d ":" -f2 | rev`
# Argument $2: stageTag=`echo "$lambdaArn" | rev | cut -d ":" -f1 | rev`

echo "##[command] $0"

if [ -z $1 ] ; then
    echo "##[error] Argument 1 {functionName} not provided."
    exit 1
elif [ -z $2 ] ; then
    echo "##[error] Argument 2 {stageTag} not provided."
    exit 1
fi

echo "##[debug] `aws lambda get-function --function-name $1`"
functionVersion=`aws lambda publish-version --function-name $1 --query "Version" --output text`
echo "##[debug] update-alias $2: $functionName:$functionVersion"

aws lambda update-alias --function-name $functionName --name $2 --function-version $functionVersion

aws lambda get-function --function-name $functionName:$2


