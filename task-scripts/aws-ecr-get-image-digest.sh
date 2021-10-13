# Argument $1: Repository Name  #pass variable from DevOps Pipeline
# Argument $2: Image Tag
# Argument $3: output variable name

echo "Describe Image: $1:$2"

if [ -z $1 ]; then
    echo "##[error] Describe Image: Argument $1 {repository name} not provided."
    exit 1
elif [ -z $2 ] ; then
    echo "##[error] Describe Image: Argument $2 {image tag} not provided."
    exit 1   
fi

imageDigest=`aws ecr describe-images --repository-name $1 --image-ids imageTag="$2" --query "imageDetails[].imageDigest" --output text`

echo "##vso[task.setvariable variable=$3]$imageDigest"

