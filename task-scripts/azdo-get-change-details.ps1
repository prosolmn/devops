param (
    
    $buildIdFrom,
    $buildIdTo,
    $version,
    $tgtFolder #$(Agent.TempDirectory)
)

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

if($null -eq $artifactAlias -Or $artifactAlias -eq ""){
    Write-Host "##[error] -artifactAlias not provided: using primary artifact"
    $buildIdTo="$env:BUILD_BUILDID"
} else {
    Write-Host "##[debug] -artifactAlias provided: $artifactAlias"
    $buildIdTo=('$env:'+"RELEASE_ARTIFACTS_$artifactAlias_BUILDID" | Invoke-Expression)
}

if($null -eq $buildId -Or $buildId -eq "" ) {
    Write-Host "##[error] buildId not found."
    exit 1
} else {
    Write-Host "##[debug] buildId found: $buildId"
}

if($null -eq $tgtFolder -Or $tgtFolder -eq "") {
    $tgtFolder = [System.IO.Path]::GetTempPath()
    Write-Host "##[debug] tgtFolder not provided; using $tgtFolder"
} else {
    Write-Host "##[debug] tgtFolder provided: $tgtFolder"
}

$outFile = $tgtFolder + "buildlog_$buildId.log"
Write-Host "##[debug] outFile: $outFile"

$url = "$env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI"+"$env:SYSTEM_TEAMPROJECT"+"_apis/build/builds/$buildId/logs?api-version=6.0"
Write-Host "##[debug] url: $url"

if($null -eq $env:SYSTEM_ACCESSTOKEN){
    Write-Host "##[error] access the OAuth token through the System.AccessToken variable is disabled."
    exit 1
}

$header = @{ Authorization = "Bearer $env:SYSTEM_ACCESSTOKEN"};

Invoke-RestMethod -Uri $url -method Get -Headers $header -OutFile $outFile;

#$outFile = "C:\Users\nparadis\Downloads\release_notes.csv"
$outFile = [System.IO.Path]::Combine("$tgtFolder", 'Release_notes.csv')

#Dim array and write headers
$outarray = @()

$responseFile = [System.IO.Path]::Combine("$tgtFolder", 'build-changes.json')

Invoke-RestMethod -Uri $url -method Get -Headers $header -OutFile $responseFile;

$response = Get-Content $responseFile -Raw | ConvertFrom-Json | Select-object -ExpandProperty value #| ConvertTo-Json
Write-Output "$response"

$response | ForEach-Object {
    $url = $_.location
    $id = $_.id
    #Write-Output "$url"

    #$responseFile = "C:\Users\nparadis\Downloadsscommit_$id.json"
    $responseFile = [System.IO.Path]::Combine("$tgtFolder", "commit_$id.json")
    #Write-Output $responseFile

    Invoke-WebRequest -Uri "$url" -Headers $header -OutFile $responseFile;
    
    $commit = Get-Content $responseFile -Raw | ConvertFrom-Json

    $outarray += New-Object PsObject -property @{
        'Id' = $_.id
        'Title' = $_.message
        'Details' = $commit.comment
        'Link' = $commit.remoteUrl
        'Datetime' = $_.timestamp
        'Commit Id'= $commit.commitId
        }
}

$outarray | Select-Object -Property 'Title', 'Details','Commit Id','Datetime','Link' | export-csv $outFile -NoTypeInformation