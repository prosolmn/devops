param(
    [Parameter(Mandatory=$true)] 
    [string] $functionName
,
    [Parameter(Mandatory=$false)] 
    [string] $alias    
,
    [Parameter(Mandatory=$true)] 
    [string] $sqs
,
    [Parameter(Mandatory=$false)] 
    [int] $batchSize = 10
)

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking  
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

#Get SQS Arn
$sqsUrl = (aws sqs list-queues --queue-name-prefix "$sqs" --query 'QueueUrls' --output text)
$sqsArn = (aws sqs get-queue-attributes --queue-url "$sqsUrl" --attribute-names 'QueueArn' --output text)
$sqsArn = 'arn:aws:sqs:us-east-1:936196109900:edge-case-unity-assets-ready-sqs'

if ($alias -like ""){
    $functions = (aws lambda list-functions --query 'Functions' --output json | ConvertFrom-Json)
    $functionArn = ($functions | Where-Object {$_.FunctionName -like "$functionName"}).FunctionArn
}else{
    $aliases = (aws lambda list-aliases --function-name $functionName --query 'Aliases' --output json | ConvertFrom-Json)
    $functionArn = ($aliases | Where-Object {$_.Name -like $alias}).FunctionArn
}
if ($null -eq $functionArn){
    Write-Host "##[warning] functionArn not found for: $functionName"
    exit 1
}
Write-Host "##[debug] functionArn found: $functionArn"

$mapDisable= @()

#Get Lambda Mapping
$eventSourceMappings = (aws lambda list-event-source-mappings --query 'EventSourceMappings' --output json | ConvertFrom-Json)
ForEach ($map in $eventSourceMappings){

    $eventSource = $map.EventSourceArn.split(":")[-1]
    $eventFunction = $map.FunctionArn
    $state = $map.State

    if(($eventSource -like "$sqs") -and !($eventFunction -like "$functionArn") -and ($state -like 'Enabled')){
    #existing from target SQS to !target function (to disable)
        $mapDisable += $map
    } elseif (!($eventSource -like "$sqs") -and ($eventSource -like 'arn:aws:sqs:*') -and ($eventFunction -like "$functionArn") -and ($state -like 'Enabled')){
    #existing from !target SQS to target function (to disable)
        $mapDisable += $map
    } elseif (($eventSource -like "$sqs") -and ($eventFunction -like "$functionArn")){ 
    #existing from target SQS to target function (to enable)
        if (($null -eq $mapTarget) -or ($map.State -like 'Enabled') -or ($mapTarget.LastModified -lt $map.LastModified)){
            $mapEnable = $map
        }   
    }
}

ForEach ($map in $mapDisable){
    Write-Host "##[debug] disabling event source mapping:" $map.UUID
    Write-Host ($map | ConvertTo-Json)
    aws lambda update-event-source-mapping --uuid $map.UUID --no-enabled
}
if ($null -ne $mapEnable){
    if ($mapEnable.BatchSize -ne $batchSize){
        Write-Host "##[debug] updating event source batch size:" $mapEnable.UUID
        aws lambda update-event-source-mapping --uuid $mapEnable.UUID --batch-size $batchSize
    }

    Write-Host "##[debug] enabling event source mapping:" $mapEnable.UUID
    $response = (aws lambda update-event-source-mapping --uuid $mapEnable.UUID --enabled --output json | ConvertFrom-Json)
    if ($response.State -like 'Enabling'){
        Write-Host "##[debug] enabling successful"
        Write-Host ($response | ConvertTo-Json)
    }else{
        Write-Host "##[error] enabling unsuccessful"
        exit 1
    }
} else {
    Write-Host "##[debug] creating new event source map"
    aws lambda create-event-source-mapping --event-source-arn $sqsArn --function-name $functionArn --batch-size $batchSize --enabled
}