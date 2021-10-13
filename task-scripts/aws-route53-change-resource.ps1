param(
    [Parameter(Mandatory=$false)] 
    [string] $stageUrl = "${env:STAGEURL}"
,
    [Parameter(Mandatory=$false)] 
    [string] $albDns
,
    [Parameter(Mandatory=$false)] 
    [string] $albName
,
    [Parameter(Mandatory=$false)] 
    [string] $reason = "AZDO Release: ${env:RELEASE_PIPELINE}:${env:RELEASE_RELEASEID}"
)

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking  
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

$stageUrl = $stageUrl.Replace("http://","")
$stageUrl = $stageUrl.Replace("https://","")

#get payload------------------------------------------------------------------------
$json = 
'{
    "Comment": "${reason}",
    "Changes": [
        {
        "Action": "UPSERT",
        "ResourceRecordSet": {
            "Name": "${stageUrl}.",
            "Type": "A",
            "AliasTarget": {
                "HostedZoneId": "${albZoneId}",
                "DNSName": "${albDns}.",
                "EvaluateTargetHealth": true
            }
        }
        }
    ]
}'
# $json = '{"Comment": "${reason}","Changes": [{"Action": "UPSERT","ResourceRecordSet": {"Name": "${stageUrl}.","Type": "A","AliasTarget": {"HostedZoneId": "${albZoneId}","DNSName": "${albDns}.","EvaluateTargetHealth": true}}}]}'

#Get Hosted Zones------------------------------------------------------------------------
$zoneIds = @()
$hostedZones=(aws route53 list-hosted-zones --query 'HostedZones' --output json | ConvertFrom-Json)
forEach ($zone in $hostedZones){
    $zoneName = ($zone.Name).Replace(".com.",".com")

    if ("$stageUrl" -like "$zoneName"){
        Write-Host "##[debug] zone found:" ($zone | ConvertTo-Json)
        $zoneIds += ($zone.Id).Split("/")[2]
    }
}
if ($null -eq $zoneIds){
    Write-Host "##[error] zoneId not found for: $stageUrl"
    exit 1
}

$loadBalancers = (aws elbv2 describe-load-balancers --query 'LoadBalancers' --output 'json' | ConvertFrom-Json)
Write-Host "##[command] aws elbv2 describe-load-balancers" 

Write-Host "##[debug] Searching for LoadBalancer matching inputs ${albName}:${albDns}"
forEach ($loadBalancer in $loadBalancers){
    if (("$albDns" -like $loadBalancer.DNSName) -Or ("$albName" -like $loadBalancer.LoadBalancerName)){
        Write-Host "##[debug] LoadBalancer found: `n"($loadBalancer | ConvertTo-Json)
        $albZoneId = $loadBalancer.CanonicalHostedZoneId
        $albDns = "dualstack."+$loadBalancer.DNSName
        $albName = $loadBalancer.LoadBalancerName
        break
    }
}
if ("$albZoneId" -eq ""){
    Write-Host "##[error] LoadBalancer not found matching inputs ${albName}:${albDns}"
    exit 1
}

$TempFile = New-TemporaryFile

forEach ($zoneId in $zoneIds){
    $jsonFile = $TempFile.FullName.Replace($TempFile.Name,"${zoneId}.json")
    Copy-Item -Path $TempFile.FullName -Destination "$jsonFile" -Force

    $change = ($ExecutionContext.InvokeCommand.ExpandString($json)) 
    Write-Host "##vso[task.uploadfile]${jsonFile}"
    Write-Host "##[debug] file://${jsonFile}: `n $change" 

    $change | Out-File -FilePath "$jsonFile" -Encoding ASCII -Force 

    Write-Host "##[command] aws route53 change-resource-record-sets --hosted-zone-id $zoneId --change-batch file://${jsonFile}"
    aws route53 change-resource-record-sets --hosted-zone-id "$zoneId" --change-batch "file://${jsonFile}"

    Remove-Item -Path $jsonFile -Force
}

Remove-Item -Path $TempFile -Force