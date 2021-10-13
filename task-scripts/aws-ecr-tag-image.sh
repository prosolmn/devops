# Argument $1: Image Name
# Argument $2: BuildId
# Argument $3: Tag

echo "##[command] $0"
verifyDigests=true

if [ -z "$1" ] ; then
    echo "##[error] Argument 1 {image name} not provided."
    exit 1
else
    echo "##[info] Argument 1 {image name}: $1"
fi

if [ -z $2 ] ; then
    echo "##[error] Argument 2 {build id} not provided."
    exit 1
else
    echo "##[info] Argument 2 {build id}: $2"
fi

if [ -z $2 ] ; then
    echo "##[error] Argument 3 {tag} not provided."
    exit 1
else
    echo "##[info] Argument 3 {tag}: $2"
fi

echo "##[info] Argument 3 {continue on <> image digest}: $3"

MANIFEST=`aws ecr batch-get-image --repository-name $1 --image-ids imageTag=$2 --query 'images[].imageManifest' --output text --profile prod`

aws ecr put-image --repository-name $1 --image-tag $3 --image-manifest "$MANIFEST"

aws ecr describe-images --repository-name $1

MANIFEST2=`aws ecr batch-get-image --repository-name $1 --image-ids imageTag=$3 --query 'images[].imageManifest' --output text` 

if [[ "$MANIFEST" == "$MANIFEST2" ]] ; then
    echo "##[info] "   
fi




