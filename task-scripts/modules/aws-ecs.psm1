Function Get-TaskNameFromArn(){
    param(
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)] 
        [string] $arn 
    )
   
    return (($arn.Split(':'))[5].Split('/'))[-1]
}

Function Get-ClusterNameFromArn(){
    param(
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)] 
        [string] $arn 
    )
   
    return (($arn.Split(':'))[-1].Split('/'))[-1]
}

Function Get-EcsTasks(){
    param(
        [Parameter(Mandatory=$false)] 
        [string] $vpcId
    ,
        [Parameter(Mandatory=$false)] 
        [string] $include = "*"
    ,
        [Parameter(Mandatory=$false)] 
        [string] $exclude
    )  

    $splat = @{
        vpcId    = "$vpcId"
    }
    $clusterArns = Get-EcsClusters @splat
    
    Write-Host "##[section] Get-EcsTasks"
    $tasks = @()

    forEach ($clusterArn in $clusterArns){
        $taskArns=(aws ecs list-tasks --cluster $clusterArn --desired-status RUNNING --query "taskArns[]" --output json | ConvertFrom-Json)
        foreach ($taskArn in $taskArns){
            $task=(aws ecs describe-tasks --cluster $clusterArn --task $taskArn --query "tasks[]" --output json | ConvertFrom-Json)
            $taskName=(Get-TaskNameFromArn -arn $task.taskDefinitionArn)
            if ($taskName -like "$include" -And $taskName -notlike "$exclude"){
                $tasks += $task
            }
        }
    }

    Write-Host "##[debug] Get-EcsTasks:" $tasks.Count "tasks found"
    return $tasks
}

Function Get-EcsClusters(){

    param(
        [Parameter(Mandatory=$false)] 
        [string] $vpcId
    ,
        [Parameter(Mandatory=$false)] 
        [string] $clusterName = "*"
    )

    Write-Host "##[section] Get-EcsClusters"

    if($vpcId -eq ''){$vpcId='*'}
    
    $clusterArns=(aws ecs list-clusters --query "clusterArns[]" --output json | ConvertFrom-Json)

    if($vpcId -eq '*'){
        Write-Host "##[debug] Get-EcsClusters:" $clusterArns.Count "clusters found"
        return $clusterArns
        exit
    }

    $ec2Instances=(aws ec2 describe-instances --filters Name=vpc-id,Values=$vpcId --query 'Reservations[].Instances[].InstanceId' --output json | convertFrom-Json)
    $clusters = @()

    forEach ($clusterArn in $clusterArns){
        $containerInstances=(aws ecs list-container-instances --cluster $clusterArn --query 'containerInstanceArns[]' --output json | ConvertFrom-Json)
        [bool] $inVpc = $false

        forEach ($containerInstance in $containerInstances){
            $ec2InstanceId=(aws ecs describe-container-instances --cluster $clusterArn --container-instance $containerInstance --query 'containerInstances[*].ec2InstanceId[]' --output text)
            if($ec2Instances.Contains($ec2InstanceId)) {
                $inVpc = $true
                break
            }
        }
        
        if ($inVpc){
            $clusters += $clusterArn
        }
    }
    
    Write-Host "##[debug] Get-EcsClusters:" $clusters.Count "clusters found"
    return $clusters
}