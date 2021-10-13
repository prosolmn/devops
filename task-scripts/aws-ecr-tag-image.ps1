param(
    [Parameter(Mandatory=$true)] 
    [string] $imageName
,
    [Parameter(Mandatory=$true)] 
    [string] $getTag
,
    [Parameter(Mandatory=$true)] 
    [ValidateScript({!("$getTag" -like "$setTag")})]
    [string] $setTag
)

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

Write-Host "##[debug] Getting image digest: ${imageName}:${getTag}"
try{
    $image = (aws ecr batch-get-image --repository-name $imageName --image-ids imageTag="$getTag" --query 'images[0]' --output json | ConvertFrom-Json)
}catch {
    Write-Host "##[error] image not found: ${imageName}:${getTag}"
    exit 1
}

$imageDigest = $image.imageId.imageDigest
$image.imageManifest

# $TempFile = New-TemporaryFile
# $jsonFile = $TempFile.FullName.Replace($TempFile.Name,$imageDigest.Replace('sha256:','')) + ".json"
# Rename-Item -Path $TempFile.FullName -NewName "$jsonFile"
# $image.imageManifest | Out-File -FilePath "$jsonFile" -Force 

aws ecr put-image --repository-name $imageName --image-tag $setTag --image-manifest file://"$jsonFile" --image-digest "$imageDigest"

try{
    $image2 = (aws ecr batch-get-image --repository-name $imageName --image-ids imageTag="$setTag" --query 'images[0]' --output json | ConvertFrom-Json)
}catch {
    Write-Host "##[error] image not found: ${imageName}:${setTag}"
}

if ($image.imageId.imageDigest -like $image2.imageId.imageDigest) {
    Write-Host "##[debug] image tagged: ${imageName}:${setTag}" $image2.imageId.imageDigest
    exit 0
} else {
    Write-Host "##[error] image NOT tagged: ${imageName}:${getTag}"
    exit 1
}