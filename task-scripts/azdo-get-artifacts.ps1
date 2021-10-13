param (
    [Parameter(Mandatory=$false)] 
    [string] $include = "*"
,
    [Parameter(Mandatory=$false)] 
    [string] $exclude = ""
,
    [Parameter(Mandatory=$false)]
    [string] $tgtFolder = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "release-artifacts_${env:RELEASE_RELEASEID}")
)

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")

if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

if ("$env:SYSTEM_ARTIFACTSDIRECTORY" -eq ""){
    Write-Host "##[error] missing SYSTEM_ARTIFACTSDIRECTORY"
    exit 1
}

if (test-path "$tgtFolder" -PathType Container){
    Write-Host "##[debug] -tgtFolder exists: $tgtFolder"
}else{
    mkdir "$tgtFolder"
    Write-Host "##[debug] -tgtFolder created: $tgtFolder"
}

$artifacts=(Get-ChildItem "$env:SYSTEM_ARTIFACTSDIRECTORY") 
$artifacts | ForEach-Object{
    $artifactAlias=(Split-Path $_.FullName -leaf).ToUpper()
    if ("$artifactAlias" -like "$include" -And "$artifactAlias" -notlike "$exclude"){
        $splat = @{
            artifactAlias = "$artifactAlias"
            tgtFolder = "$tgtFolder"
        }
        Get-Artifact @splat
    }
}