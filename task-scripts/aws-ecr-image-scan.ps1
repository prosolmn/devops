param(
    [Parameter(Mandatory=$true)] 
    [string] $repoName
,
    [Parameter(Mandatory=$true)] 
    [string] $tag
,
    [Parameter(Mandatory=$true)] 
    [string] $resultsPath
)

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

Function Test-ScanFindings{
    param(
        [Parameter(ValueFromPipeline=$true,Mandatory=$true)] 
        [psobject] $scanFindings
    )   

    Write-Host "##[command] Test-scanFindings"

    $results = @()
    $result=[PSCustomObject]@{
        Name='';
        Result='';
        Message=''
    }

    $vars=(Get-ChildItem -Path Env:\)
    ForEach ($var in $vars){
        If ($var.Name -like 'AWS_SCAN_*'){
            $severity = ($var.Name -split "_")[2]
            $countThreshold = $var.Value
            
            $severities = @()
            $severities += $severity
            switch ($severity){
                'CRITICAL' {}
                'HIGH'{
                    $severities += 'CRITICAL'
                }
                'MEDIUM'{
                    $severities += 'CRITICAL'
                    $severities += 'HIGH'
                }
                'LOW'{
                    $severities += 'CRITICAL'
                    $severities += 'HIGH'
                    $severities += 'MEDIUM'
                }
                'INFORMATIONAL'{
                    $severities += 'CRITICAL'
                    $severities += 'HIGH'
                    $severities += 'MEDIUM'
                    $severities += 'LOW'
                }
                'UNDEFINED'{}
            }

            $result.Name = "Evaluate-AwsEcrImageVulnerabilities_${severity}"

            [int] $subtotal = ($scanFindings.findingSeverityCounts.PSObject.Properties | Where-Object {$_.Name -in $severities} | Measure-Object -Property 'Value' -Sum).Sum

            if($subtotal -le $countThreshold){
                $result.Result = 'passed'
                $result.Message = "${severity} vulnerability count [${subtotal}] <= threshold [${countThreshold}]"
                Write-Host "##[info]" $result.Message
            }else {
                $result.Result = 'failed'
                $result.Message = "${severity} vulnerability count [${subtotal}] > threshold [${countThreshold}]"
                Write-Host "##[warning]" $result.Message
            }

            $results += $result.PSObject.Copy()
        }
    }

    return $results
}

(aws ecr wait image-scan-complete --repository-name $repoName --image-id imageTag=$tag)

$imageScan=(aws ecr describe-image-scan-findings --repository-name $repoName --image-id imageTag=$tag --output json | ConvertFrom-Json)
Write-Host "##[command] aws ecr describe-image-scan-findings --repository-name $repoName --image-id imageTag=$tag"
Write-Host ($imageScan.imageScanFindings.findings | ConvertTo-Json)

$results = @()
$results = (Test-ScanFindings -scanFindings ($imageScan.imageScanFindings))

if ($null -ne $results){
    $splat = @{
        fileName    = $PSCommandPath;
        tgtPath     = "$resultsPath"
        results     = $results
    }

    $resultsFile=(Write-JunitXml @splat)
    Write-Host "##[info] test results saved to: $resultsFile"
} else {
    Write-Host "##[debug] results empty; no policy threshholds found matching AWS_SCAN_*"
}