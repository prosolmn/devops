param(
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string] $targetFile
,
    [Parameter(Mandatory=$false)] 
    [string]  $env = "null"
,
    [Parameter(Mandatory=$false)] 
    [string]  $area = "null"
)

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

$file = (Get-Content -path $targetFile -Raw)

if("$area" -eq "null" -Or "$env" -eq "null") {
    Write-Host "##[debug] -Find/Replace params not provided."
} else {

    $splat = @{
        filename    = "$area";
        env         = "$env";
    }

    $variables = Get-Env @splat
    If (!($null -eq $variables -Or "$variables" -eq "")){
        foreach ($variable in $variables) {
            Write-Host "##[command] Find: $variable.key :: Replace : $variable.value"
            $file = ($file -replace $variable.key, $variable.value)

            $file_env = $targetFolder + $variable.filename + ".env"
            $val = $variable.key + "=" + $variable.value
            Write-Host "##[command] -Path $file_env -Value $val"
            Add-Content -Path $file_env -Value $val -Force
        }
    }
}

try {
    $file = ($ExecutionContext.InvokeCommand.ExpandString($file))
} catch {
    Write-Host ("##[error] $_.ScriptStackTrace")
    Write-Host ("##[error] $_")
}

Write-host ($file)
Set-Content -Path $targetFile -Value "$file" -Force

"##[debug] exiting: $LASTEXITCODE"
exit $LASTEXITCODE