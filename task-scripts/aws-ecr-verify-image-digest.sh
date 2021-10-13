# Argument $1: Image Name
# Argument $2: Stage Name
# Argument $3: continue on image digest <>

echo "##[command] $0"
verifyDigests=true

if [ -z "$1" ] ; then
    echo "##[error] Argument 1 {image name} not provided."
    exit 1
else
    echo "##[info] Argument 1 {image name}: $1"
fi

if [ -z $2 ] ; then
    echo "##[error] Argument 2 {image tag} not provided."
    exit 1
else
    echo "##[info] Argument 2 {image tag}: $2"
fi

if [ -z $3 ] ; then
    fail=false
else
    fail=$3
fi
echo "##[info] Argument 3 {continue on <> image digest}: $3"

repositories=`aws ecr describe-repositories --query "repositories[].repositoryName" --output text`
verifyDigest=true

for repository in $repositories ; do
    
    if [[ "$repository" == "$1" ]] ; then
        echo "##[debug] Getting image digest for $repository:$2"
        targetImageDigest=`aws ecr describe-images --repository-name $repository --image-ids imageTag="$2" --query "imageDetails[].imageDigest" --output text`
        if [ -z $targetImageDigest ]; then
            echo "##[error] ImageDigest not found: $repository:$2:"
            #exit 1
        else
            echo "##[info] ImageDigest found $repository:$2:$targetImageDigest"

            taskName="$repository-task-$2"
            clusterArns=`aws ecs list-clusters --query "clusterArns[]" --output text`

            for clusterArn in $clusterArns ; do
                #echo "##[debug] Checking cluster for $taskName: $clusterArn"
                taskArns=`aws ecs list-tasks --cluster $clusterArn --desired-status RUNNING --query "taskArns[]" --output text`
                                
                for taskArn in $taskArns ; do
                    taskDef=`aws ecs describe-tasks --cluster $clusterArn --task $taskArn --query "tasks[].taskDefinitionArn" --output text`
                    #echo "##[debug] Checking cluster for $taskName: $clusterArn:$taskDef"

                    if [[ "$taskDef" == *"$taskName"* ]] ; then
                        echo "##[debug] Getting image digest for task: $taskDef:$taskArn"
                        aws ecs wait tasks-running --cluster $clusterArn --tasks $taskArn                       
                        imageDigest=`aws ecs describe-tasks --cluster $clusterArn --task $taskArn --output text --query "tasks[].containers[].imageDigest"`
                        echo "##[debug] Getting image digest for task: $taskDef:$taskArn:$imageDigest"
                        
                        echo "##[debug] Verifying image digest: $targetImageDigest:$imageDigest"
                        if [[ $imageDigest == $targetImageDigest ]] ; then
                            echo "##[info] Image digest verified: $targetImageDigest:$imageDigest"
                        else
                            verifyDigests=false
                            echo "##[error] Image digest not verified: $targetImageDigest:$imageDigest"
                            if [[ $fail == "true" ]] ; then
                                echo "##[debug] Exit on error: image digest does not match"
                                write-junitxml "failed"
                                exit 1
                            fi  
                        fi
                    fi
                done
            done
        fi
    fi
done

if [ "$verifyDigests" = true ] ; then
    echo "##[info] All RUNNING tasks utilizing tagged image"
    exit 0
else
    echo "##[error] All RUNNING tasks not utilizing tagged image"
    exit 1
fi



    




