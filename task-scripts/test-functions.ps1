#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

 
$splat = @{
    sourceCsv   = "C:\Users\nparadis\infra\aws-config\env.csv";
    filename    = "api-gateway";
    env         = "dev";
    debug       = $true;
}

$variables = Get-Env @splat

foreach ($variable in $variables) {
    Write-Host $variable.key = $variable.value
}
