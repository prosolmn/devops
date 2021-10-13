param(
    [Parameter(Mandatory=$true)] 
    [ValidateScript({Test-Path $_})]
    [string] $path
,
    [Parameter(Mandatory=$false)] 
    [string] $include = "*"
,
    [Parameter(Mandatory=$false)] 
    [string] $exclude = ""
)

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------


$hash=(Get-Hash -path "$path" -include "$include" -exclude "$exclude" -Verbose:$VerbosePreference)

Write-Host $hash