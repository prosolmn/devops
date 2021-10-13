param (
    $artifactAlias,
    $tgtFolder
)

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

if($null -eq $artifactAlias -Or $artifactAlias -eq ""){
    Write-Host "##[error] -artifactAlias not provided: using primary artifact"
    $buildId="$env:BUILD_BUILDID"
} else {
    Write-Host "##[debug] -artifactAlias provided: $artifactAlias"
    $buildId=('$env:'+"RELEASE_ARTIFACTS_$artifactAlias_BUILDID" | Invoke-Expression)
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
    Write-Host "##[error] access to the OAuth token through the System.AccessToken variable is disabled."
    exit 1
}

$header = @{ Authorization = "Bearer $env:SYSTEM_ACCESSTOKEN"};

Invoke-RestMethod -Uri $url -method Get -Headers $header -OutFile $outFile;

$logs = Get-Content $outFile -Raw | ConvertFrom-Json | Select-object -ExpandProperty value #| ConvertTo-Json
$logs | ForEach-Object {
    $logId = ""
    $logId += $_.id
    
    $url = ""
    $url += $_.url
    
    Write-Host "url: $url"

    $outFile = $tgtFolder + "log_$logId.log"
    Write-Host "##[debug] outFile: $outFile"
    
    Invoke-WebRequest -Uri $url -method Get -Headers $header -OutFile $outFile;
}

$splat = @{
  Path = $tgtFolder + "*.log"
  CompressionLevel = "Fastest"
  DestinationPath = $tgtFolder + "BuildLog_$artifactAlias_$buildId.zip"
}
Compress-Archive @splat