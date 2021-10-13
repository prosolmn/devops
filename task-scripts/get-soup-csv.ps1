param(
    [Parameter(Mandatory=$false)] 
    [string] $projectName = "${env:BUILD_DEFINITIONNAME}"
,
    [Parameter(Mandatory=$false)] 
    [string]  $versionName = "${env:BUILD_SOURCEBRANCHNAME}"
,
    [Parameter(Mandatory=$false)] 
    [string]  $outFile = [System.IO.Path]::GetTempPath() + "${projectName}_${versionName}-components.csv"
)

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

Function outputCsv(){
    param(
        [Parameter(Mandatory=$true)] 
        [psobject] $soup
    ,
        [Parameter(Mandatory=$true)] 
        [string]  $outfile
    )
    
    $soup.PSObject.Properties | ForEach-Object { 
        if( $_.Value -like "" -Or $null -eq $_.Value){
            $_.Value = 'n/a'
        }
    }

    $soup | Select-Object -Property 'Name', 'Description', 'Usage', 'Version', 'License', 'ChangeAnalysis', 'RiskAssessment', 'RiskJustification', 'Developer', 'ApprovalStatus', 'URL', 'Language' | export-csv $outFile -Append -NoTypeInformation
}

    
    $soup= New-Object PsObject -property @{
        Name=""
        Description=""
        Usage=""
        Version=""
        License=""
        ChangeAnalysis=""
        RiskAssessment=""
        RiskJustification=""
        Developer=""
        ApprovalStatus=""
        URL=""
        Language=""
    }

    $splat = @{
        projectName = "$projectName";
        versionName = "$versionName";
    }
    $componentVersions = (Get-SynopsysComponentVersions @splat)

    ForEach($componentVersion in $componentVersions){

        $soup.PSObject.Properties | ForEach-Object { 
            $_.Value = ""
        }
        
        $soup.Name = $componentVersion.componentName
        $soup.Description = $componentVersion.component_description
        $soup.Version = $componentVersion.componentVersionName
        $soup.Usage = ($componentVersion.usages | Out-String)
        $soup.License = $componentVersion.licenses.licenseDisplay
        $soup.ApprovalStatus = $componentVersion.approvalStatus
        $soup.URL = $componentVersion.component_url
        $soup.Language = $componentVersion.component_primaryLanguage
        $soup.Developer = "${env:BUILD_REQUESTEDFOR}"

        #Add any custom fields here

        $splat = @{
            soup    = $soup;
            outFile = "$outFile"
        }
        outputCsv @splat
    }

    Write-Host "##[debug] components written to: $outFile"
    