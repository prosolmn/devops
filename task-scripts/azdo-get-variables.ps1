param(
    [Parameter(Mandatory=$true)] 
    [ValidateScript({Test-Path $_ -PathType Container})]
    [string] $tgtFolder
,
    [Parameter(Mandatory=$false)]
    [string] $project = "$env:SYSTEM_TEAMPROJECT"
)

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

$outFile = [System.IO.Path]::Combine("$tgtFolder","${project}_libraries.csv")
Clear-Content -Path $outFile -Force

$splat = @{
    libraryName    = "*";
    project       = "$project"
}

$libraries=Get-Library @splat

foreach ($library in $libraries) {
    $library | Select-Object -Property 'libraryId', 'libraryName', 'variableName', 'variableValue', 'isSecret' | export-csv $outFile -Append -NoTypeInformation
}