Function Get-SynopsysHeader(){
    param(
        [Parameter(Mandatory=$true)] 
        [string] $URI
    ,
        [Parameter(Mandatory=$true)] 
        [string]  $APItoken
    )

    Write-Host "##[command] Get-SynopsysHeader -URI $URI"

    try{

        # Force the Invoke-RestMethod PowerShell cmdlet to use TLS 1.2
        Clear-Host all 
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
        $bearerToken = ""
    
        $authHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $authHeaders = @{}
        $authHeaders.Add("Authorization","token ${APIToken}")
    
        #user the API token to create a bearer token for this session
        $authResponse = Invoke-WebRequest -Method Post -Headers $authHeaders -Uri ($URI + "/tokens/authenticate")
        $csrfToken = $authResponse.Headers.'X-CSRF-TOKEN'
        $authHeaders.Add("X-CSRF-TOKEN", $csrfToken)
    
        $responseJSON = $authResponse | ConvertFrom-JSON
        $bearerToken = $responseJSON.bearerToken
        $authHeaders["Authorization"] = "bearer ${bearerToken}"
        
        return $authHeaders

    } catch {

        $_.Exception
        Write-Host $error[0].Exception

        Exit 1
    }
}

Function Get-SynopsysLink(){
    param(
        [Parameter(Mandatory=$true)] 
        [psobject] $links
    ,
        [Parameter(Mandatory=$true)] 
        [string]  $rel
    )

    ForEach( $link in $links ){
        if ( $link.rel -like "$rel" ){
            $href = $link.href
            break
        }
    }

    return "$href"
}

Function Get-SynopsysRiskCountTypeCount(){
    param(
        [Parameter(Mandatory=$true)] 
        [psobject] $riskProfile
    ,
        [Parameter(Mandatory=$true)] 
        [string]  $countType
    )

    ForEach($count in $riskProfile.counts){
        If ($count.countType -like "$countType"){
            $riskCount = $count.count
            break
        }
    }

    return $riskCount
}
Function Get-SynopsysComponentVersions(){
    param(
        [Parameter(Mandatory=$true)] 
        [string] $projectName
    ,
        [Parameter(Mandatory=$true)] 
        [string]  $versionName
    ,
        [Parameter(Mandatory=$false)] 
        [string]  $URI = "${env:BD_APIURI}"
    )

    # Get Auth Header
    $authHeaders = @{}
    $splat = @{
        URI         = "$URI";
        APItoken    = "${env:BD_APITOKEN}"
    }
    $authHeaders = (Get-SynopsysHeader @splat)

    Write-Host "##[command] Get-SynopsysComponentVersions -projectName $projectName -versionName $versionName"
    
    # Get Project Details
    $projectURI = $URI + "/projects?q=name%3A${projectName}"

    $projects = (Invoke-WebRequest -Method Get -Headers $authHeaders -Uri ($projectURI) | ConvertFrom-JSON | Select-object -ExpandProperty 'items')
    $projectURI = $projects[0]._meta.href

    $splat = @{
        links   = $projects[0]._meta.links;
        rel     = "versions"
    }
    $versionsURI = (Get-SynopsysLink @splat)

    # Get Version Details
    $projectVersions = (Invoke-WebRequest -Method Get -Headers $authHeaders -Uri ($versionsURI) | ConvertFrom-JSON | Select-object -ExpandProperty 'items')
    ForEach ($projectVersion in $projectVersions){
        if ( $projectVersion.versionName -like "$versionName" ){
            
            $splat = @{
                links   = $projectVersion._meta.links;
                rel     = "components"
            }
            $componentsURI = (Get-SynopsysLink @splat)
            break
        }
    }
    
    $componentVersions = (Invoke-RestMethod -Method GET -Headers $authHeaders -Uri ($componentsURI)).items

    ForEach($componentVersion in $componentVersions){
        $component = (Invoke-RestMethod -Method GET -Headers $authHeaders -Uri ($componentVersion.component))

        $component.PSObject.Properties | ForEach-Object { 
            $componentVersion  | Add-Member -Name ("component_"+$_.Name) -Type NoteProperty -Value $_.Value
        }
    }

    return $componentVersions

}