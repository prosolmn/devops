param(
        [Parameter(ValueFromPipeline=$true, Mandatory=$false)] 
        [string] $stageName = "${env:STAGENAME}"
    ,
        [Parameter(Mandatory=$false)]
        [string] $description = "AZDO Release.DeploymentId: ${env:RELEASE_DEPLOYMENTID}"
    )

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

#Deploy Frontend
$splat = @{
    apiId       = "$env:AWS_APIIDFRONTEND";
    stageName   = "${stageName}";
    sourceJson  = "apigateway-prophecy-frontend.json"
}
Update-ApiGateway @splat

#Deploy Backend
$splat = @{
    apiId       = "$env:AWS_APIIDBACKEND";
    stageName   = "${stageName}";
    sourceJson  = "apigateway-prophecy-backend.json"
}
Update-ApiGateway @splat

exit $LASTEXITCODE 