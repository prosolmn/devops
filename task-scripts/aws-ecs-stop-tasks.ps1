param(
    [Parameter(Mandatory=$false)] 
    [string] $vpcId = "${env:AWS_VPCID}"
,
    [Parameter(Mandatory=$false)] 
    [string] $taskName = "*"
,
    [Parameter(Mandatory=$false)] 
    [string] $reason = "AZDO Release: ${env:RELEASE_PIPELINE}:${env:RELEASE_RELEASEID}"
,
    [Parameter(Mandatory=$false)] 
    [bool] $wait
)

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking  
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

#Get ECS Tasks------------------------------------------------------------------------
$splat = @{
    include   = "$taskName";
    vpcId    = "$vpcId"
}

$tasks=Get-EcsTasks @splat

If (("${env:BUILD_SOURCEBRANCH}" -like "*/release*") -or ("${env:BUILD_SOURCEBRANCH}" -like "develop")){
    $wait = $true
}

$tasksStopped = @()

#Stop first round of services------------------------------------------------------------------------
forEach ($task in $tasks){
    if (!($tasksStopped.taskDefinitionArn -contains $task.taskDefinitionArn)){
        Write-Host "##[debug] Stopping task:" $task.taskArn
        aws ecs stop-task --cluster $task.clusterArn --task $task.taskArn --reason "$reason" --query "task.[clusterArn,taskDefinitionArn,desiredStatus,lastStatus]" --output table

        $tasksStopped += $task
    }    
}

#wait for services to restart------------------------------------------------------------------------
If ($wait){
    Write-Host "##[command] Start-Sleep"
    Start-Sleep -s 300
    Write-Host "##[debug] resuming"
} 

#Stop second round of services------------------------------------------------------------------------
forEach ($task in $tasks){
    if (!($tasksStopped.taskArn -contains $task.taskArn)){
        Write-Host "##[debug] Stopping task:" $task.taskArn
        aws ecs stop-task --cluster $task.clusterArn --task $task.taskArn --reason "$reason" --query "task.[clusterArn,taskDefinitionArn,desiredStatus,lastStatus]" --output table

        $tasksStopped += $task
    }
}

#Verify stopped services------------------------------------------------------------------------
forEach ($task in $tasks){
    Write-Host "##[debug] waiting for task stopped:" $task.clusterArn $task.containers.name
    aws ecs wait tasks-stopped --cluster $task.clusterArn --tasks $task.taskArn
    Write-Host "##[debug] task stopped:" $task.clusterArn $task.containers.name
}