param
    (
        [Parameter(Mandatory=$false)] 
        [string] 
        $releaseId = "$env:RELEASE_RELEASEID"
    ,
        [Parameter(Mandatory=$false)] 
        [string] 
        $tgtFolder = [System.IO.Path]::GetTempPath()
    )

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

if($null -eq $env:SYSTEM_ACCESSTOKEN){
    Write-Host "##[error] access the OAuth token through the System.AccessToken variable is disabled."
    exit 1
}

$header = @{Authorization = "Bearer $env:SYSTEM_ACCESSTOKEN"}

#get release
$releaseName = "ReleaseLogs_" + $releaseId
$tgtFolder = [System.IO.Path]::Combine("$tgtFolder", "${env:RELEASE_DEFINITIONNAME}","${env:RELEASE_RELEASENAME}")

if (test-path "$tgtFolder" -PathType Container){
    Write-Host "##[debug] -tgtFolder exists: $tgtFolder"
}else{
    mkdir "$tgtFolder"
    Write-Host "##[debug] -tgtFolder created: $tgtFolder"
}

$outFile = [System.IO.Path]::Combine("$tgtFolder","${releaseName}.json")
Write-Host "##[debug] release json outFile: $outFile"

$url = "$env:SYSTEM_COLLECTIONURI"+"$env:SYSTEM_TEAMPROJECT"+"/_apis/release/releases/" + $releaseId
Write-Host "##[debug] release json url: $url"

Invoke-WebRequest -Uri $url -method Get -Headers $header -OutFile $outFile

#get logs
$outFile = $tgtFolder + "ReleaseLogs_" + $releaseId + ".zip"
Write-Host "##[debug] release logs outFile: $outFile"

$url = $url + "/logs"
Write-Host "##[debug] release logs url: $url"

Invoke-RestMethod -Uri $url -method Get -Headers $header -OutFile $outFile

#get link
try{
    $wshShell = New-Object -ComObject "WScript.Shell"
    $urlShortcut = $wshShell.CreateShortcut("${tgtFolder}${releaseName}.url")
    $urlShortcut.TargetPath = "${env:RELEASE_RELEASEWEBURL}"
    $urlShortcut.Save()
} catch {}




