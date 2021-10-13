param(
    [Parameter(Mandatory=$true)] 
    [string] $apiId
,
    [Parameter(Mandatory=$true)] 
    [string] $stageName
,
    [Parameter(Mandatory=$false)] 
    # [ValidateScript({Test-Path $_ -PathType 'Leaf'})]
    [string]  $tgt = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "RESTAPI_${apiId}_${stageName}.json")
)

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

Write-Host "##[debug] exporting apigatway $apiId/$stageName to: $tgt"
aws apigateway get-export --parameters extensions='integrations' --rest-api-id $apiId --stage-name $stageName --export-type swagger "$tgt"