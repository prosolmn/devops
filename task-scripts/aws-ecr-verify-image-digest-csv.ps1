param(
    [Parameter(Mandatory=$false)] 
    [string] $envName = "${env:AWS_ENV}"
,
    [Parameter(Mandatory=$false)] 
    [string] $tag = $envName
,
    [Parameter(Mandatory=$false)] 
    [string] $vpcId = "${env:AWS_VPCID}"
,
    [Parameter(Mandatory=$false)] 
    # [ValidateScript({Test-Path $_ -PathType 'Leaf'})]
    [string]  $outFile = [System.IO.Path]::GetTempPath() + "image-digest_${tag}_${envName}.csv"
)

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

Function outputCsv([string]$outFile, $artifact){
    $artifact.PSObject.Properties | ForEach-Object { 
        if( $_.Value -eq "" -Or $null -eq $_.Value){
            $_.Value = 'n/a'
        }
    }

    $artifact | Select-Object -Property 'Environment', 'Tag', 'Name', 'BuildNo', 'imageDigest', 'task', 'taskId', 'cluster', 'verifyDigest' | export-csv $outFile -Append -NoTypeInformation
}

$artifact= New-Object PsObject -property @{
    Name=""
    Environment=""
    Tag=""
    VPC=""
    BuildNo=""
    imageDigest=""
    task=""
    taskId=""
    cluster=""
    verifyDigest=""
}

#Get ECS Tasks------------------------------------------------------------------------
$splat = @{
    taskName    = "*-task-${envName}*";
    vpcId       = "$vpcId"
}
$tasks=Get-EcsTasks @splat
if($vpcId -eq ''){$vpcId='n/a'}

$repositories=(aws ecr describe-repositories --query "repositories[].repositoryName" --output json | ConvertFrom-Json)

foreach($repository in $repositories) {
    
    $artifact.PSObject.Properties | ForEach-Object { 
        $_.Value = ""
    }
    
    $artifactAlias=($repository).ToUpper()
    
    $artifact.Name="$artifactAlias"
    $artifact.Environment="$envName"
    $artifact.Tag="$tag"
    $artifact.VPC="$vpcId";

    $artifact.BuildNo=(Get-ChildItem -Path ('env:RELEASE_ARTIFACTS_'+"$artifactAlias"+'_BUILDNUMBER')).Value

    Write-Host "##[debug] Getting image digest for $repository : $tag"
    $targetImageDigest=(aws ecr describe-images --repository-name $repository --image-ids imageTag="$tag" --query "imageDetails[].imageDigest" --output text)

    if ("$targetImageDigest" -eq "" -Or $null -eq $targetImageDigest){
        Write-Host "##[error] ImageDigest not found: ${r}epository}:${envName}"
        outputCsv -outFile $outFile -artifact $artifact
    }else{
        Write-Host "##[info] ImageDigest found ${repository}:${envName}: ${targetImageDigest}"
        $artifact.imageDigest="$targetImageDigest"
        $taskName="$repository-task-${envName}"
    
        foreach($task in $tasks) {
            if ($task.taskDefinitionArn -Like "*$taskName*"){
                Write-Host "##[debug] Getting image digest for task:" $task.clusterArn'/'$task.containers.name
                aws ecs wait tasks-running --cluster $task.clusterArn --tasks $task.taskArn                       
                                
                Write-Host "##[debug] Verifying image digest: $targetImageDigest : $imageDigest"
                if ($task.containers.imageDigest -eq "$targetImageDigest"){  
                    $artifact.verifyDigest="OK";
                    $artifact.task=$task.taskDefinitionArn
                    $artifact.taskId=$task.taskArn
                    $artifact.cluster=$task.clusterArn
                    outputCsv -outFile $outFile -artifact $artifact
                }else{
                    $artifact.verifyDigest="";
                    $artifact.task=""
                    $artifact.taskId=""
                    $artifact.cluster=""
                    $artifact.verifyDigest="NOK";
                    outputCsv -outFile $outFile -artifact $artifact
                }
            }
        }

        If($artifact.verifyDigest -eq ""){
            $artifact.verifyDigest="";
            $artifact.task=""
            $artifact.taskId=""
            $artifact.cluster=""
            $artifact.verifyDigest="NOK";
            outputCsv -outFile $outFile -artifact $artifact
        }
    }
}