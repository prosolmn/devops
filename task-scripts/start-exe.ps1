param(
    [Parameter(Mandatory=$true)] 
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string] $targetFile
,
    [Parameter(Mandatory=$false)]
    [int] $sleep = 1
)

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

$targetName = (Get-Item $targetFile).BaseName
$targetPath = (Get-Item $targetFile).DirectoryName.Replace('\','\\')
$targetExe = $targetName + (Get-Item $targetFile).Extension

Write-Host "##[command] starting: $targetName"
# Start-Process cmd.exe -WorkingDirectory "$targetPath" -ArgumentList {"START $targetExe disown"} -PassThru | Format-List *
Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine="$targetFile";CurrentDirectory = "$targetPath"}

Write-Host "##[debug] sleeping for: $sleep"
Start-Sleep -s $sleep
Write-Host "##[debug] Get-Process details:"
Get-Process -name "$targetName" | Format-List *

"##[debug] LASTEXITCODE: $LASTEXITCODE"
exit $LASTEXITCODE
