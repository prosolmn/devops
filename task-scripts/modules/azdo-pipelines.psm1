Function Get-BuildLogs(){   
    param(
        [Parameter(Mandatory=$true)]
        [string] $tgtFolder
    ,
        [Parameter(Mandatory=$true)]
        [string] $artifactAlias
    )

    Write-Host "##[command] Get-BuildLogs for: $artifactAlias"

    if($null -eq $env:SYSTEM_ACCESSTOKEN){
        Write-Host "##[error] access the OAuth token through the System.AccessToken variable is disabled."
        exit 1
    }

    $header = @{ Authorization = "Bearer $env:SYSTEM_ACCESSTOKEN"}
    $buildProject=(Get-ChildItem -Path ("env:RELEASE_ARTIFACTS_${artifactAlias}_PROJECTNAME")).Value
    $url = "${env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI}${buildProject}/_apis/build/builds/${buildId}/logs?api-version=6.0"
    Write-Host("##[debug] url: $url")

    $outFolder = [System.IO.Path]::Combine("${tgtFolder}", 'build-logs')
    mkdir "$outFolder"

    $response = (Invoke-WebRequest -Uri $url -method Get -Headers $header)
    $logs = $response | ConvertFrom-Json | Select-object -ExpandProperty value
    $logs | ForEach-Object {
        $logId = ""
        $logId += $_.id
        
        $url = ""
        $url += $_.url
        
        Write-Host "url: $url"

        $outFile = [System.IO.Path]::Combine("${outFolder}","${logId}.log")
        Write-Host "##[debug] outFile: $outFile"
        
        Invoke-WebRequest -Uri $url -method Get -Headers $header -OutFile $outFile;
    }

    Write-Host "##[debug] compress: ${outFolder}\*"
    $splat = @{
        Path = [System.IO.Path]::Combine("${outFolder}", '*')
        CompressionLevel = "Optimal"
        DestinationPath = "${outFolder}.zip"
    }
    Compress-Archive @splat

    #delete folder
    try{
        # Get-ChildItem -Path "${outFolder}" -Include * -Recurse | Remove-Item
        Remove-Item -Path "$outFolder" -Recurse -Force
    }catch{
        Write-Host ("##[error] $_.ScriptStackTrace")
        Write-Host ("##[error] $_")
    }
}

Function Get-ArtifactDetails(){
    param(
        [Parameter(Mandatory=$true)] 
        [string] $tgtFolder
    ,
        [Parameter(Mandatory=$true)]
        [string] $artifactAlias
    )

    Write-Host "##[command] Get-ArtifactDetails for: $artifactAlias"

    if($null -eq $env:SYSTEM_ACCESSTOKEN){
        Write-Host "##[error] access the OAuth token through the System.AccessToken environment variable is disabled."
        exit 1
    }

    $header = @{ Authorization = "Bearer $env:SYSTEM_ACCESSTOKEN"}
    $buildProject=(Get-ChildItem -Path ("env:RELEASE_ARTIFACTS_${artifactAlias}_PROJECTNAME")).Value
    $repoId=(Get-ChildItem -Path ("env:RELEASE_ARTIFACTS_${artifactAlias}_REPOSITORY_ID")).Value

    $url = "${env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI}${buildProject}/_apis/git/repositories/${repoId}?api-version=4.1"
    Write-Host "##[debug] url: $url"
    $response=(Invoke-WebRequest -Uri $url -method Get -Headers $header | ConvertFrom-Json)
   
    $artifact= New-Object PsObject -property @{
        Name="$artifactAlias"
        BuildNo=(Get-ChildItem -Path ("env:RELEASE_ARTIFACTS_${artifactAlias}_BUILDNUMBER")).Value
        ArtifactType=(Get-ChildItem -Path ("env:RELEASE_ARTIFACTS_${artifactAlias}_TYPE")).Value
        RepoName=(Get-ChildItem -Path ("env:RELEASE_ARTIFACTS_${artifactAlias}_REPOSITORY_NAME")).Value
        RepoUrl=$response.webUrl
        Branch=(Get-ChildItem -Path ("env:RELEASE_ARTIFACTS_${artifactAlias}_SOURCEBRANCH")).Value
        Commit=(Get-ChildItem -Path ("env:RELEASE_ARTIFACTS_${artifactAlias}_SOURCEVERSION")).Value
        BuildPipeline=(Get-ChildItem -Path ("env:RELEASE_ARTIFACTS_${artifactAlias}_DEFINITIONNAME")).Value
        ReleaseName="$env:RELEASE_RELEASENAME"
        ReleaseWebUrl="$env:RELEASE_RELEASEWEBURL"
        ReleaseStartTime="$env:RELEASE_DEPLOYMENT_STARTTIME"
    }

    $artifact.PSObject.Properties | ForEach-Object { 
        if( $_.Value -eq "" -Or $null -eq $_.Value){
            $_.Value = 'n/a'
        }
    }

    $outProps = (
        'Name', 
        'buildNo', 
        'ArtifactType', 
        'RepoName', 
        'RepoUrl', 
        'Branch', 
        'Commit', 
        'BuildPipeline',
        'ReleaseName',
        'ReleaseWebUrl',
        'ReleaseStartTime'
    )

    $outFile = [System.IO.Path]::Combine("${tgtFolder}", 'version-description.csv')
    Write-Host "##[debug] write to: $outFile"
    $artifact | Select-Object -Property $outProps | export-csv $outFile -Append -NoTypeInformation -Force

    Write-Host "##[debug] checking share drive"
    $share = [System.IO.Path]::Combine("${env:DEVOPS_SHARE}", "${env:DEVOPS_RELEASETARGETFOLDER}")
    if (test-path "${share}" -PathType Container){
        Write-Host "##[debug] checking share drive: connected"

        [bool] $exists = $false
        $outFile = [System.IO.Path]::Combine("${share}", 'version-description.csv')

        if (test-path "$outFile" -PathType Leaf){
            $csv = import-csv $outFile
            
            foreach($line in $csv) {  
                If($line.Name -like $artifact.Name -and $line.buildNo -like $artifact.buildNo){
                    $exists = $true
                    break
                }
            }
        }

        if ($exists -eq $false){
            Write-Host "##[debug] add record to: $outFile"
            $artifact | Select-Object -Property $outProps | export-csv $outFile -Append -NoTypeInformation -Force
        } else {
            Write-Host "##[debug] record already exists: $outfile"
        }
    } else {
        Write-Host "##[debug] checking share drive: not connected"
    }
}

Function Get-Artifact(){
    param(
        [Parameter(Mandatory=$true)] 
        [string] $tgtFolder
    ,
        [Parameter(Mandatory=$false)]
        [string] $artifactAlias = "${env:BUILD_DEFINITIONNAME}"
    )

    $artifactAlias=($artifactAlias.ToUpper())
    Write-Host "##[command] Get-Artifact for: $artifactAlias"
    
    $buildId=(Get-ChildItem -Path ("env:RELEASE_ARTIFACTS_${artifactAlias}_BUILDID")).Value
    if($null -eq $buildId -Or $buildId -eq "" ) {
        Write-Host "##[error] buildId not found."
        exit 1
    } else {
        Write-Host "##[debug] buildId found: $buildId"
    }

    $buildProject=(Get-ChildItem -Path ("env:RELEASE_ARTIFACTS_${artifactAlias}_PROJECTNAME")).Value
    if($null -eq $buildProject -Or $buildProject -eq "" ) {
        $buildProject = "$env:SYSTEM_TEAMPROJECT"
        Write-Host "##[warning] buildProject not found; using: $buildProject"
    }else{
        Write-Host "##[debug] buildProject: $buildProject"
    }

    if($null -eq $tgtFolder -Or $tgtFolder -eq "") {
        $tgtFolder = [System.IO.Path]::GetTempPath()
        Write-Host "##[debug] tgtFolder not provided; using $tgtFolder"
    }

    $tgtFolder = [System.IO.Path]::Combine("${tgtFolder}", "${artifactAlias}")

    if (test-path $tgtFolder -PathType Container){
        Write-Host "##[debug] -tgtFolder exists: $tgtFolder"
    }else{
        mkdir $tgtFolder
        Write-Host "##[debug] -tgtFolder created: $tgtFolder"
    }
    
    #copy artifact ----------------------------------------------
    $splat = @{
        Path = [System.IO.Path]::Combine("${env:SYSTEM_ARTIFACTSDIRECTORY}", "${artifactAlias}", '*')
        CompressionLevel = "Optimal"
        DestinationPath = [System.IO.Path]::Combine("${tgtFolder}", "${artifactAlias}.zip")
    }
    Compress-Archive @splat

    #get build logs ----------------------------------------------
    Get-BuildLogs -artifactAlias "$artifactAlias" -tgtFolder "$tgtFolder"
    
    #get artifact details ----------------------------------------------
    Get-ArtifactDetails -artifactAlias "$artifactAlias" -tgtFolder "$tgtFolder"
}