param(
    [Parameter(Mandatory=$false)] 
    [string] $vpcId = "${env:AWS_VPCID}"
,
    [Parameter(Mandatory=$false)] 
    [string] $clusterName = "*"
)

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking  
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

$splat = @{
    vpcId       = "$vpcId"
    clusterName = "$clusterName"
}
$clusterArns = Get-EcsClusters @splat

foreach($clusterArn in $clusterArns){

    if ( ${clusterArn}.toLower() -like "*${clusterName}*".ToLower()) {
        Write-Host "##[info] Updating container instances on cluster: $clusterArn"

        $containerInstanceArns=(aws ecs list-container-instances --cluster $clusterArn --status ACTIVE --query "containerInstanceArns[]" --output json | ConvertFrom-Json)

        foreach($containerInstanceArn in $containerInstanceArns) {

            $version=(aws ecs describe-container-instances --cluster $clusterArn --container-instances $containerInstanceArn --query "containerInstances[*].versionInfo.agentVersion" --output text)
            Write-Host "##[info] Updating container instance $containerInstanceArn from v${version}:"
            try{
                aws ecs update-container-agent --cluster $clusterArn --container $containerInstanceArn --query "containerInstance.agentUpdateStatus" --output text 
            } catch {
                Write-Host $_
            }
        }
    }       
}
