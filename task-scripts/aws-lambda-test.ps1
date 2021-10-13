param(
    [Parameter(Mandatory=$false)]
    [string] $alias = '$LATEST'
)
    
#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

#get payload------------------------------------------------------------------------
$json = 
'{
    "surgeon": {
      "emailAddress": "prophecy-dev@stryker.com",
      "firstName": "Test",
      "lastName": "Stryker"
    },
    "salesRep": {
      "emailAddress": "prophecy-dev@wright.com",
      "firstName": "Test",
      "lastName": "Wright"
    },
    "patientId": "alias:#ALIAS#",
    "downloadLink": "#LINK#",
    "homeUrl": "#LINK#",
    "prophecyTeamEmailAddress": "prophecy-dev@wright.com",
    "uploaderEmail": "prophecy-dev@wright.com",
    "uploaderName": "Test, DevOps",
    "caseNumber": "alias:#ALIAS#",
    "partFamily": "inbone"
}'

$json = $json.Replace('#LINK#',"${env:RELEASE_RELEASEWEBURL}")
$json = $json.Replace('#ALIAS#',"${alias}")

Write-Host "##[debug] payload:"
Write-Host $json

$splat = @{
    functionName    = "Email_CaseCreated";
    alias           = "$alias"
    payload         = "$json"
}
Invoke-Lambda @splat

$splat = @{
    functionName    = "Email_ScanReceived";
    alias           = "$alias"
    payload         = "$json"
}
Invoke-Lambda @splat

$splat = @{
    functionName    = "Email_CaseUpdated";
    alias           = "$alias"
    payload         = "$json"
}
Invoke-Lambda @splat