param(
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [string] $path1
,
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [string] $path2
,
    [Parameter(Mandatory=$false)] 
    [string]  $resultsPath = [System.IO.Path]::GetTempPath()
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

$hash1=(Get-Hash -path "$path1" -include "$include" -exclude "$exclude" -Verbose:$VerbosePreference)
Write-Host "##[debug] path1:${path1}:SHA1:${hash1}"
$hash2=(Get-Hash -path "$path2" -include "$include" -exclude "$exclude" -Verbose:$VerbosePreference)
Write-Host "##[debug] path2:${path2}:SHA1:${hash2}"

if ($null -eq $hash1 -Or $hash1 -eq ""){
    Write-Host "##[error] hash error."
    $result=[PSCustomObject]@{
        Name='verify-hash';
        Result='error';
        Message="Hash is empty for $path1"
    }
}elseif ("$hash1" -eq "$hash2"){
    Write-Host "##[info] hashes equal."
    $result=[PSCustomObject]@{
        Name='verify-hash';
        Result='passed';
        Message="${algorithm}: $hash1"
    }
}else{
    $result=[PSCustomObject]@{
        Name='verify-hash';
        Result='failure';
        Message="${algorithm} hashes are not equal ${path1}:${hash1}::${path2}:${hash2}"
    }
    Write-Host "##[warning] hashes not equal."
}

Write-JunitXml -fileName "$PSCommandPath" -tgtPath "$resultsPath" -results $result
exit $LASTEXITCODE