param (
    $sourceJson,
    $targetCsv
)

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

if($null -eq $sourceJson -Or $sourceJson -eq "") {
    Write-Host "##[error] -sourceJson not provided."
    exit 1
} elseif (!(test-path $sourceJson -PathType Leaf)){ 
    Write-Host "##[error] -sourceJson not found: $sourceJson"
    exit 1
} else {
    Write-Host "##[error] -sourceJson provided: $sourceJson"
}

if($null -eq $targetCsv -Or $targetCsv -eq "") {
    $targetCsv=[System.IO.Path]::GetTempPath() + (Get-Item $sourceJson).BaseName + ".csv"

    Write-Host "##[debug] -targetCsv not provided; using: $targetCsv"
} else {
    Write-Host "##[debug] -targetCsv provided: $targetCsv"
}

$dependencies = @()

$source = (Get-Content "$sourceJson" -Raw | ConvertFrom-Json)
# $source = (Get-Content "$sourceJson" -Raw | ConvertFrom-Json | Select-object -ExpandProperty value)

# $source.PSObject.Properties | ForEach-Object { 
$source| ForEach-Object { 


    # $attributes = $_.Value   

    # $dependencies += New-Object PsObject -property @{
    #     'Name' = $_.Name
    #     'Version' = $attributes.version
    #     'Source' = $attributes.source
    #     'Url' = $attributes.url
    # }
}

(Get-Content "$sourceJson" -Raw | 
    ConvertFrom-Json) | 
    ConvertTo-Csv -NoTypeInformation |
    Set-Content $targetCsv

# $dependencies | Select-Object -Property 'Name', 'Version', 'Source', 'Url' | export-csv $targetCsv -Append -NoTypeInformation

