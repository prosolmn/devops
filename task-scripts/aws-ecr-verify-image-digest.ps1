param(
    [Parameter(Mandatory=$true)] 
    [string] $repoName
,
    [Parameter(Mandatory=$true)] 
    [string] $envName
,
    [Parameter(Mandatory=$false)] 
    [string] $tag = $envName
,
    [Parameter(Mandatory=$false)] 
    [string] $vpcId = "${env:AWS_VPCID}"
,
    [Parameter(Mandatory=$true)] 
    # [ValidateScript({Test-Path $_})]
    [string] $resultsPath
)

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

[bool] $verifyDigests=$true
[int] $verifyCount = 0
[int] $taskCount = 0
$results = @()

#Get ECS Tasks------------------------------------------------------------------------
Write-Host "##[debug] Getting ecs tasks for vpc: $vpcId"
$envName = ($ExecutionContext.InvokeCommand.ExpandString($envName))

$splat = @{
    include    = "${repoName}-task-${envName}";
    vpcId       = "$vpcId"
}

$tasks=Get-EcsTasks @splat

Write-Host "##[debug] Getting repositories"
$repositories=(aws ecr describe-repositories --query "repositories[].repositoryName" --output json | ConvertFrom-Json)

foreach($repository in $repositories) {
    if($repository -Like $repoName){
        Write-Host "##[debug] Getting image digest for ${repository}:${tag}"
        $targetImageDigest=(aws ecr describe-images --repository-name $repository --image-ids imageTag="$tag" --query "imageDetails[].imageDigest" --output text)

        if ("$targetImageDigest" -eq "" ){
            Write-Host "##[error] ImageDigest not found: ${repository}:${tag}"
            $results+=[pscustomobject]@{Name='ecr-describe-images';result='error';message="digest not found for repo $repository"}
        }else{
            Write-Host "##[info] ImageDigest found ${repository}:${tag}:${targetImageDigest}"
            $results+=[pscustomobject]@{Name='ecr-describe-images';Result='passed';Message="digest found for repo $repository"}
            
            $taskName="${repository}-task-${envName}"
                   
            foreach($task in $tasks) {
                if ($task.taskDefinitionArn -Like "*$taskName*"){
                    $taskCount += 1
                    Write-Host "##[debug] Getting image digest for task:" $task.clusterArn'/'$task.containers.name
                    aws ecs wait tasks-running --cluster $task.clusterArn --tasks $task.taskArn 

                    $imageDigest=$task.containers.imageDigest
                    Write-Host "##[debug] Getting image digest for task:" $task.clusterArn'/'$task.containers.name':'$imageDigest
                    
                    Write-Host "##[debug] Verifying image digest: $targetImageDigest : $imageDigest"
                    if ( "$imageDigest" -eq "$targetImageDigest" ){
                        $results+=[pscustomobject]@{Name='verify-digest';Result='passed';Message="digest verified for task $task.taskArn : $imageDigest"}
                        Write-Host "##[info] Image digest verified: $targetImageDigest = $imageDigest"
                        $verifyCount += 1
                    }else{
                        $verifyDigests=$false
                        $results+=[pscustomobject]@{Name='verify-digest';Result='failure';Message="digest invalid for task $task.taskArn : $imageDigest"}
                        Write-Host "##[error] Image digest invalid: $targetImageDigest <> $imageDigest"  
                    }
                }
            }
        }
    }
}

if ($verifyCount -eq $taskCount -and $taskCount -gt 0){
    Write-Host "##[info] (${verifyCount}/${taskCount}) All RUNNING tasks utilizing tagged image"
}elseif ($taskCount -eq 0){
    Write-Host "##[warning] (${verifyCount}/${taskCount}) No RUNNING tasks match search criteria"
}else{
    Write-Host "##[warning] (${verifyCount}/${taskCount}) All RUNNING tasks NOT utilizing tagged image"
}
$resultsFile=(Write-JunitXml -fileName $MyInvocation.MyCommand.Path -tgtPath "$resultsPath" -results $results)
Write-Host "##[info] test results saved to: $resultsFile"




