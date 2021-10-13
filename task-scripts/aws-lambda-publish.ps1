param(
    [Parameter(Mandatory=$true)] 
    [string] $functionName
,
    [Parameter(Mandatory=$true)]
    [string] $alias
)
    
#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

#Update Environment Variables------------------------------------------------------------------------
$baseName = $functionName.Replace("-$alias","")
$splat = @{
    functionName    = "$baseName";
    env             = "$alias";
}
Update-LambdaVariables @splat

#Get Latest Version------------------------------------------------------------------------
Write-Host "##[debug] publish-version [latest] $functionName"
$functionVersion=(aws lambda publish-version --function-name $functionName --query "Version" --output text)

#Check for Alias------------------------------------------------------------------------
try {
    $verifyAlias=(aws lambda get-alias --function-name $functionName --name $alias)
} catch {}
if($null -eq $verifyAlias -Or "$verifyAlias" -eq ""){
    Write-Host "##[debug] create-alias "$alias" for "$functionName":"$functionVersion
    Write-Host "##[debug] "(aws lambda create-alias --function-name $functionName --name $alias --function-version $functionVersion)
}else {
    Write-Host "##[debug] update-alias "$alias" to "$functionName":"$functionVersion
    Write-Host "##[debug] "(aws lambda update-alias --function-name $functionName --name $alias --function-version $functionVersion)
}

$functionName+=":$alias"
Write-Host "##[debug] "(aws lambda get-function --function-name $functionName)

exit $LASTEXITCODE 