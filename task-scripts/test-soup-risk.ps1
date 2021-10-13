param(
    [Parameter(Mandatory=$false)] 
    [string] $projectName = "${env:BUILD_DEFINITIONNAME}"
,
    [Parameter(Mandatory=$false)] 
    [string]  $versionName = "${env:BUILD_SOURCEBRANCHNAME}"
,
    [Parameter(Mandatory=$false)] 
    [string]  $resultsPath = [System.IO.Path]::GetTempPath()
)

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

Function Get-SynopsysProjectRisk{
    param(
        [Parameter(Mandatory=$true)] 
        [psobject] $riskProfile
    ,
        [Parameter(Mandatory=$true)] 
        [psobject] $riskType
    )   
    
    Write-Host "##[command] Get-SynopsysProjectRisk -riskType $riskType"

    $projectRisk = @()
    $riskTemplate = New-Object -TypeName PsObject -Property @{riskType = "${riskType}"; countType = ''; count = 0} 
    
    ForEach($count in $riskProfile[0].counts){
        $riskTemplate.countType = $count.countType
        $projectRisk += ($riskTemplate.PsObject.Copy())
    }
    
    ForEach($count in $projectRisk){
        $count.count = ($riskProfile.counts | Where-Object {$_.countType -like $count.countType} | Measure-Object -Property 'count' -Sum).Sum
    }

    return $projectRisk
}

Function Test-SynopsysProjectRisk{
    param(
        [Parameter(ValueFromPipeline=$true,Mandatory=$true)] 
        [psobject] $riskProfile
    )   

    Write-Host "##[command] Test-SynopsysProjectRisk"

    $results = @()
    $result=[PSCustomObject]@{
        Name='';
        Result='';
        Message=''
    }

    $vars=(Get-ChildItem -Path Env:\)
    ForEach ($var in $vars){
        If ($var.Name -like 'BD_RISK_*'){
            $riskType = ($var.Name -split "_")[2]
            $countType = ($var.Name -split "_")[3]
            $countThreshold = $var.Value
            
            $countTypes = @()
            $countTypes += $countType
            switch ($countType){
                'CRITICAL' {}
                'HIGH'{
                    $countTypes += 'CRITICAL'
                }
                'MEDIUM'{
                    $countTypes += 'CRITICAL'
                    $countTypes += 'HIGH'
                }
                'LOW'{
                    $countTypes += 'CRITICAL'
                    $countTypes += 'HIGH'
                    $countTypes += 'MEDIUM'
                }
                'OK'{
                    $countTypes += 'CRITICAL'
                    $countTypes += 'HIGH'
                    $countTypes += 'MEDIUM'
                    $countTypes += 'LOW'
                }
                'UNKNOWN'{}
            }

            $result.Name = "Evaluate-SysnopsysProjectRisk_${riskType}_${countType}"
            $subtotal = ($riskProfile | Where-Object {$_.countType -in $countTypes  -and $_.riskType -like "$riskType"} | Measure-Object -Property 'count' -Sum).Sum

            if($subtotal -le $countThreshold){
                $result.Result = 'passed'
                $result.Message = "${riskType} ${countType} risk count [${subtotal}] <= threshold [${countThreshold}]"
                Write-Host "##[info]" $result.Message
            }else {
                $result.Result = 'failed'
                $result.Message = "${riskType} ${countType} risk count [${subtotal}] > threshold [${countThreshold}]"
                Write-Host "##[warning]" $result.Message
            }

            $results += $result.PSObject.Copy()

        }
    }

    return $results
}

Function Test-SynopsysProjectApproval{
    param(
        [Parameter(Mandatory=$true)] 
        [psobject] $componentVersions
    )   
    
    Write-Host "##[command] Test-SynopsysProjectApproval"

    ForEach($componentVersion in $componentVersions){
        If (!($componentVersion.reviewStatus -in ('REVIEWED','APPROVED'))){
            Write-Host "##[warning] Component review status warning:" $componentVersion.componentName $componentVersion.componentVersionName "["$componentVersion.reviewStatus"]"
            Write-Host "##[info] to review component:" $componentVersion.componentVersion
        }
    }
}

$splat = @{
    projectName = "$projectName";
    versionName = "$versionName";
}
$componentVersions = (Get-SynopsysComponentVersions @splat)

$projectRisk = @()
$projectRisk += (Get-SynopsysProjectRisk -riskProfile $componentVersions.licenseRiskProfile -riskType 'license')
$projectRisk += (Get-SynopsysProjectRisk -riskProfile $componentVersions.securityRiskProfile -riskType 'security')
$projectRisk += (Get-SynopsysProjectRisk -riskProfile $componentVersions.versionRiskProfile -riskType 'version')
$projectRisk += (Get-SynopsysProjectRisk -riskProfile $componentVersions.operationalRiskProfile -riskType 'operational')

$results = @()
$results = (Test-SynopsysProjectRisk -riskProfile $projectRisk)

if ($null -ne $results){
    $splat = @{
        fileName    = $PSCommandPath;
        tgtPath     = "$resultsPath"
        results     = $results
    }

    $resultsFile=(Write-JunitXml @splat)
    Write-Host "##[info] test results saved to: $resultsFile"
} else {
    Write-Host "##[debug] results empty; no policy threshholds found matching BD_RISK_*"
}

Test-SynopsysProjectApproval -componentVersions $componentVersions