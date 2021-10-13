param(
    [Parameter(Mandatory=$false)] 
    [string] $targetPath = "*"
,
    [Parameter(Mandatory=$false)] 
    [string] $targetName = "*"
)

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

if($targetPath -eq "*" -And $targetName -eq "*") {
    Write-Host "##[error] -targetPath and -targetName not provided."
    exit 1
} elseif (test-path $targetPath -PathType Leaf){ 
    Write-Host "##[debug] -targetPath found as file: $targetPath"
    $targetName = (Get-Item $targetPath).BaseName
} elseif (test-path $targetPath -PathType Container){ 
    Write-Host "##[debug] -targetPath found as path: $targetPath"
    $targetPath = "${targetPath}*"
} else {
    Write-Host "##[error] -targetPath not found: $targetPath"
    exit 1
}

Write-Host "##[debug] Get-Process details: $targetName"
$processes = (Get-Process -name "$targetName")

foreach($process in $processes) {
    If($process.path -like "$targetPath"){
        Write-Host "##[debug] Stopping:" ${process}.name ${process}.id
        Stop-Process -InputObject $process -Force
    }
}

"##[debug] exiting: $LASTEXITCODE"
exit $LASTEXITCODE