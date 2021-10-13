param(
    [Parameter(Mandatory=$false)] 
    [string] $include = "*"
,
    [Parameter(Mandatory=$false)] 
    [string] $exclude
,
    [Parameter(Mandatory=$false)] 
    [string] $outFile = [System.IO.Path]::GetTempPath() + "package-verification.csv"
,
    [Parameter(Mandatory=$false)] 
    [string] $vpcId
)

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

Function outputCsv(){
    param(
        [Parameter(Mandatory=$true)] 
        [string]$outFile
    ,
        [Parameter(Mandatory=$true)] 
        [PSCustomObject] $outArray
    ,
        [Parameter(Mandatory=$true)] 
        $properties
    )

    $outArray.PSObject.Properties | ForEach-Object { 
        if( $_.Value -eq "" -Or $null -eq $_.Value){
            $_.Value = 'n/a'
        }
    }

    Write-Verbose "##[debug] write record to: $outFile"
    $outArray | Select-Object -Property $properties | export-csv $outFile -Append -NoTypeInformation  
    
    Write-Verbose "##[debug] checking share drive"
    $share = [System.IO.Path]::Combine("${env:DEVOPS_SHARE}", "${env:DEVOPS_RELEASETARGETFOLDER}")
    if (test-path "${share}" -PathType Container){
        Write-Verbose "##[debug] checking share drive: connected"

        $outFile = [System.IO.Path]::Combine("${share}", 'package-verification.csv')

        Write-Verbose "##[debug] add record to: $outFile"
        $outArray | Select-Object -Property $properties | export-csv $outFile -Append -NoTypeInformation -Force
    } else {
        Write-Verbose "##[debug] checking share drive: not connected"
    }

}

$properties = @(
    'datetime',
    'releaseName'
    'environment',
    'vpc',
    'cluster',
    'name',
    'task',
    'taskId',
    'taskTag',
    'taskImageDigest',
    'verifyDigest',
    'ecrTags',
    'imagePushedAt'
)

$propHash = @{}
ForEach ($property in $properties){
    $propHash.add($property,'')
}

Write-Verbose "##[debug] create array"
$outArray= New-Object PsObject -property $propHash

#Get ECS Tasks------------------------------------------------------------------------
if("$vpcId" -eq "" -or $null -eq $vpcId){
    $vpcId = "${env:AWS_VPCID}"
}

$splat = @{
    include     = "$include"
    exclude     = "$exclude"
    vpcId       = "$vpcId"
}

$tasks=Get-EcsTasks @splat
[int] $count = 0

foreach($task in $tasks) {
    
    $clusterName = (Get-ClusterNameFromArn -arn $task.clusterArn)
    $containerName = $task.containers.name
    Write-Host "##[debug] Getting image digest for task: ${clusterName}/${containerName}"

    aws ecs wait tasks-running --cluster $task.clusterArn --tasks $task.taskArn                       
    $targetImageDigest = $task.containers.imageDigest
    
    $containerDefinition = (aws ecs describe-task-definition --task-definition $task.taskDefinitionArn --query 'taskDefinition.containerDefinitions[]' --output json | ConvertFrom-Json)
    $tag = ($containerDefinition.image).split(':')[1]

    $outArray.PSObject.Properties | ForEach-Object { 
        $_.Value = ""
    }
    
    $outArray.datetime = (Get-Date -Format "yyyy/MM/dd HH:mm:ss")
    $outArray.releaseName = "$env:RELEASE_RELEASENAME"
    $outArray.environment="$env:AWS_ENV"
    $outArray.vpc="$vpcId"
    $outArray.cluster=$task.clusterArn
    $outArray.name=$containerDefinition.Name
    $outArray.task=$task.taskDefinitionArn
    $outArray.taskId=$task.taskArn
    $outArray.taskTag="$tag"
    $outArray.taskImageDigest="$targetImageDigest"

    if ("$targetImageDigest" -ne ""){
        $image = (aws ecr describe-images --repository-name $containerDefinition.Name --image-ids imageTag=$tag --query 'imageDetails' --output json | ConvertFrom-Json)

        Write-Host "##[debug] Verifying image digest: $targetImageDigest"
        if ($image.imageDigest -eq "$targetImageDigest"){  
            $outArray.verifyDigest="OK";
            $outArray.ecrTags=($image.imageTags -join ', ')
            $outArray.imagePushedAt=$image.imagePushedAt.Substring(0,10) + " " + $image.imagePushedAt.Substring(11,8)
        }else{
            $outArray.verifyDigest="NOK";
        }
    }
    
    outputCsv -outFile $outFile -outArray $outArray -properties $properties
    $count += 1
}

Write-Host "##[debug]" $count "Records written to: $outFile"
