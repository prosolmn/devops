# Argument $1: bucket-name
# Argument $2: object-key
# Argument $3: TagSet [{Key=string,Value=string},{Key=string,Value=string}]

echo "##[command] S3 Tag Objects"

if [ -z $1 ] ; then
    echo "##[error] S3 Tag Objects: Arg[1] bucket-name not provided."
    exit
elif [ -z $2 ] ; then
    echo "##[error] S3 Tag Objects: Arg[2] object-key not provided."
    exit
elif [ -z $3 ] ; then
    echo "##[error] S3 Tag Objects: Arg[3] TagSet not provided e.g. {Key=string,Value=string},{Key=string,Value=string}"
    exit
fi

tagSet="TagSet=[$3]"
s3objects=`aws s3api list-objects --bucket $1 --query "Contents[].Key" --output text`

for s3object in $s3objects ; do
    
    if [[ "${s3object,,}" == "${2,,}" ]] ; then
        echo "##[info] tagging: $s3object :: $3"
        aws s3api put-object-tagging --bucket $1 --key $s3object --tagging "$tagSet"
        echo "##[info] tagging: $s3object: complete"
        echo `aws s3api get-object-tagging --bucket $1 --key $s3object --output yaml`
    fi
done
