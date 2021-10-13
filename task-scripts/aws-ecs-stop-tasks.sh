# Argument $1: Task Definition
# Argument $2: Reason RELEASE_PIPELINE:$RELEASE_RELEASEID)
# Argument $3: (boolean) wait for restart

if [ -z $1 ] ; then
    echo "##[error] Restart task: Arg1 {taskDef} not provided."
    exit 1
elif [ -z $2 ] ; then
    2="$RELEASE_PIPELINE:$RELEASE_RELEASEID"
    echo "##[debug] Restart task: Arg2 {reason} not provided. using: $2"
fi

clusterArns=`aws ecs list-clusters --query "clusterArns[]" --output text`
declare -a tasksStopped

for clusterArn in $clusterArns ; do
    taskArns=`aws ecs list-tasks --cluster $clusterArn --desired-status RUNNING --query "taskArns[]" --output text`

    for taskArn in $taskArns ; do
        taskDef=`aws ecs describe-tasks --cluster $clusterArn --task $taskArn --query "tasks[].taskDefinitionArn" --output text`
        #containerArns=`aws ecs describe-tasks --cluster $clusterArn --task $taskArn --query "tasks[].containers[].containerArn" --output text`
        if [[ "$taskDef" == *"$1"* ]] ; then
                echo "Stopping task: $taskDef : $taskArn"
                aws ecs stop-task --cluster $clusterArn --task $taskArn --reason "$2"
                tasksStopped+="$clusterArn|$taskArn "
        fi
    done
done

for taskStopped in $tasksStopped ; do
    clusterArn=`echo $taskStopped | cut -d'|' -f1`
    taskArn=`echo $taskStopped | cut -d'|' -f2`
    echo "##[debug] waiting for task stopped: $clusterArn:$taskArn"
    echo "##[debug] `aws ecs wait tasks-stopped --cluster $clusterArn --tasks $taskArn`"
    echo "##[debug] task stopped: $clusterArn:$taskArn"
done


