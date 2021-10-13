param(
    [Parameter(Mandatory=$true)] 
    [string] $bucket
,
    [Parameter(Mandatory=$false)] 
    # [ValidateScript({Test-Path $_ -PathType 'Leaf'})]
    [string]  $outFile = [System.IO.Path]::Combine("${env:AGENT_TEMPDIRECTORY}", "${bucket}.csv")
)

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

$outarray = @()

$objects = (aws s3api list-objects-v2 --bucket "$bucket" --query 'Contents[]' --output json --profile prod | ConvertFrom-Json)

ForEach ($object in $objects) {
    $outarray += New-Object PsObject -property @{
        'Bucket' = "$bucket"
        'Key' = $object.Key
        'LastModified' = $object.LastModified.Substring(0,10) + " " + $object.LastModified.Substring(11,8)
        'ETag' = $object.ETag
        'Size' = $object.Size
        'StorageClass' = $object.StorageClass
    }
}

$outProps = (
    'Key',
    'LastModified',
    'ETag',
    'Size',
    'StorageClass'
)

$outarray | Select-Object -Property $outProps  | export-csv $outFile -NoTypeInformation -Force