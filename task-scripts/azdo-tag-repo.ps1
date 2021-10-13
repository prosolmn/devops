param(
    [Parameter(Mandatory=$true)] 
    [string] $tag
,
    [Parameter(Mandatory=$true)]
    [string] $artifactAlias
)

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

$repoId=('$env:'+"RELEASE_ARTIFACTS_$artifactAlias_REPOSITORY_ID" | Invoke-Expression)
if($null -eq $repoId -Or $repoId -eq ""){
    Write-Host "##[error] -repoId not found."
    exit 1
} else {
    Write-Host "##[debug] -repoId found: $repoId"
}

$sourceVersion=('$env:'+"RELEASE_ARTIFACTS_$artifactAlias_SOURCEVERSION" | Invoke-Expression)
if($null -eq $sourceVersion -Or $sourceVersion -eq ""){
    Write-Host "##[error] -sourceVersion not found."
    exit 1
} else {
    Write-Host "##[debug] -sourceVersion found: $sourceVersion"
}

$url = "$env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI"+"$env:SYSTEM_TEAMPROJECT"+"/_apis/git/repositories/$repoId/annotatedtags?api-version=6.0-preview.1";
Write-Host "##[debug] url: $url"

$body = @{
        "name" = "$tag"
        "taggedObject" = @{
            "objectId" = "$sourceVersion"
        }
        "message" = "Release $env:RELEASE_RELEASENAME"
}  | ConvertTo-Json -Depth 3;

if($null -eq $env:SYSTEM_ACCESSTOKEN){
    Write-Host "##[error] access the OAuth token through the System.AccessToken variable is disabled."
    exit 1
}

$header = @{ Authorization = "Bearer $env:SYSTEM_ACCESSTOKEN"};

$response = Invoke-RestMethod -Uri $url -method post -Headers $header -Body $body -ContentType "application/json";
Write-Host "##[debug] resonse: $response"
    