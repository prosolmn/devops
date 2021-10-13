param(
    [Parameter(Mandatory=$true)] 
    [string] $stageName
,
    [Parameter(Mandatory=$false)] 
    [string] $fileSearch = "*"
,
    [Parameter(Mandatory=$false)] 
    [string]  $targetFolder = [System.IO.Path]::GetTempPath()
,
    [Parameter(Mandatory=$false)] 
    [string]  $targetS3Bucket
,
    [Parameter(Mandatory=$false)] 
    [string] $fileSuffix
)

#HEADER------------------------------------------------------------------------
    $scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
    if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
    (Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking  
    Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

$fileSuffix = $ExecutionContext.InvokeCommand.ExpandString($fileSuffix)
$targetS3Bucket = $ExecutionContext.InvokeCommand.ExpandString($targetS3Bucket)

Write-Host "##[command] clear existing files like: ${fileSearch}${fileSuffix}.env"
Clear-Content -Path "$targetFolder*" -Filter "${fileSearch}${fileSuffix}.env" -Force

$splat = @{
    filename    = "$fileSearch";
    env         = "$stageName";
    debug       = $false;
}

$variables = Get-Env @splat
If (!($null -eq $variables -Or "$variables" -eq "")){
    foreach ($variable in $variables) {
        $file_env = $targetFolder + $variable.filename + "${fileSuffix}.env"
        $val = $variable.key + "=" + $variable.value
        Write-Host "##[command] -Path $file_env -Value $val"
        Add-Content -Path $file_env -Value $val -Force
    }
}

If("${targetS3Bucket}" -ne ""){
    aws s3 cp "$targetFolder" "s3://${targetS3Bucket}" --exclude "*" --include "${fileSearch}${fileSuffix}.env" --recursive
}

Write-Host "##[debug] exiting: $LASTEXITCODE"

exit $LASTEXITCODE