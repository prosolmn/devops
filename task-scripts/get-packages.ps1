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
    W
    
}

if($null -eq $targetCsv -Or $targetCsv -eq "") {
    $targetCsv=[System.IO.Path]::GetTempPath() + (Get-Item $sourceJson).BaseName + ".csv"

    Write-Host "##[debug] -targetCsv not provided; using: $targetCsv"
# } elseif (!(test-path $targetCsv -PathType Leaf)){ 
#     Write-Host "##[error] -targetCsv not found: $targetCsv"
#     exit 1
} else {
    Write-Host "##[debug] -targetCsv provided: $targetCsv"
}

$dependencies = @()

$source = (Get-Content "$sourceJson" | Out-String | ConvertFrom-Json | Select-object -ExpandProperty 'dependencies')

$source.PSObject.Properties | ForEach-Object { 
    
    $attributes = $_.Value   

    $dependencies += New-Object PsObject -property @{
        'Name' = $_.Name
        'Version' = $attributes.version
        'Source' = $attributes.source
        'Url' = $attributes.url
    }
}

$dependencies | Select-Object -Property 'Name', 'Version', 'Source', 'Url' | export-csv $targetCsv -Append -NoTypeInformation

