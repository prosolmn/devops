param(
    [Parameter(Mandatory=$true)] 
    [string] $libraryName
,
    [Parameter(Mandatory=$false)]
    [string] $project = "$env:SYSTEM_TEAMPROJECT"
,
    [Parameter(Mandatory=$false)]
    [bool] $overwrite = $true
)

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

$splat = @{
    libraryName = "$libraryName";
    project     = "$project"
    overwrite   = $overwrite
}

Set-Library-Env @splat