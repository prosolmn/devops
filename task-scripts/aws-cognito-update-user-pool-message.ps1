param (
    $cognitoPoolId, 
    $sourceHtml 
    )

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

if($null -eq $cognitoPoolId -Or $cognitoPoolId -eq ""){
    Write-Host "##[debug] -cognitoPoolId not provided"
    exit 1
} else {
    Write-Host "##[debug] -cognitoPoolId provided: $cognitoPoolId"
}

if($null -eq $sourceHtml -Or $sourceHtml -eq "" ) {
    $sourceHtml = [System.IO.Path]::Combine(".", "aws-config","cognito-email-verification-message.html")
    Write-Host "##[debug] -sourceHtml not provided; using $sourceHtml"
    #exit 1
} else {
    Write-Host "##[debug] -sourceHtml provided: $sourceHtml"
}
if (!(test-path $sourceHtml -PathType Leaf)){
    Write-Host "##[error] -sourceHtml not found: $sourceHtml"
    exit 1
}

$sourceHtml = "file://"+$sourceHtml
# $html = (Get-Content -Path $sourceHtml)

aws cognito-idp update-user-pool --user-pool-id $cognitoPoolId --email-verification-message $sourceHtml

exit $LASTEXITCODE