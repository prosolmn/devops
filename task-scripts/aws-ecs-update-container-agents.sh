# Argument $1: Cluster Def  #pass variable from DevOps Pipeline
echo "Update agents"

if [ -z $1 ]; then
    echo "##[error] Restart task: Argument 1 {cluster} not provided."
    exit 1
fi

clusterArns=`aws ecs list-clusters --query "clusterArns[]" --output text`

for clusterArn in $clusterArns ; do
    
    cluster=`aws ecs describe-clusters --cluster $clusterArn --query "clusters[].clusterName" --output text`

    if [[ "${cluster,,}" == *"${1,,}"* ]] ; then
        echo "##[info] Updating container instances on cluster: $cluster"
        containerInstanceArns=`aws ecs list-container-instances --cluster $clusterArn --status ACTIVE --query "containerInstanceArns[]" --output text`
        for containerInstanceArn in $containerInstanceArns ; do

            version=`aws ecs describe-container-instances --cluster $clusterArn --container-instances $containerInstanceArn --query "containerInstances[*].versionInfo.agentVersion" --output text`
            echo "##[info] Updating container instance $containerInstanceArn from v$version:"
            echo "##[debug] `aws ecs update-container-agent --cluster $clusterArn --container $containerInstanceArn --query "containerInstance.agentUpdateStatus" --output text 2>&1`"            
        done
    fi
done
