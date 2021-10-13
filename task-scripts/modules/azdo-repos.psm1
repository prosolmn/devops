<#
    .DESCRIPTION
     Gets array of changes from Azure REST API of provided project, repository, and commit Id
    .OUTPUTS
    Array of changes for provided commit
#>
Function Get-CommitChanges{
    param(
        [Parameter(Mandatory=$false)]
        [string] $project = "${env:SYSTEM_TEAMPROJECT}"
    ,
        [Parameter(Mandatory=$false)]
        [string] $repositoryId = "${env:BUILD_REPOSITORY_NAME}"
    ,
        [Parameter(Mandatory=$false)]
        [string] $commitId = "${env:BUILD_SOURCEVERSION}"
    )
    
    Write-Host "##[command] Get-CommitChanges: ${commitId}"

    $url = "${env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI}${project}/_apis/git/repositories/${repositoryId}/commits/${commitId}/changes"
    Write-Host "##[debug] url: $url"

    if($null -eq $env:SYSTEM_ACCESSTOKEN){
        Write-Host "##[error] access the OAuth token through the System.AccessToken variable is disabled."
        exit 1
    }

    $header = @{ Authorization = "Bearer $env:SYSTEM_ACCESSTOKEN"};

    $changes = (Invoke-WebRequest -Uri "$url" -Headers $header | ConvertFrom-Json | Select-object -ExpandProperty 'changes')
    # $changes = Get-Content ([System.IO.Path]::Combine("${env:USERPROFILE}",'downloads','commits.json')) -Raw | ConvertFrom-Json | Select-object -ExpandProperty 'changes'

    Write-Host "##[debug] commit changes found:" $changes.Count
    Write-Host ($changes | ConvertTo-Json | Out-String)

    return $changes
}
Function Get-PullRequestCommits{
    param(
        [Parameter(Mandatory=$false)]
        [string] $project = "${env:SYSTEM_TEAMPROJECT}"
    ,
        [Parameter(Mandatory=$false)]
        [string] $repositoryId = "${env:BUILD_REPOSITORY_NAME}"
    ,
        [Parameter(Mandatory=$false)]
        [string] $pullRequestId = "${env:BUILD_PULLREQUEST_ID}"
    )
    
    Write-Host "##[command] Get-PullRequestCommits"

    $url = "${env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI}${project}/_apis/git/repositories/${repositoryId}/pullRequests/${pullRequestId}/commits"
    Write-Host "##[debug] url: $url"

    if($null -eq $env:SYSTEM_ACCESSTOKEN){
        Write-Host "##[error] access the OAuth token through the System.AccessToken variable is disabled."
        exit 1
    }

    $header = @{ Authorization = "Bearer $env:SYSTEM_ACCESSTOKEN"};

    $commits = (Invoke-WebRequest -Uri "$url" -Headers $header | ConvertFrom-Json | Select-object -ExpandProperty 'value')
    # $commits = Get-Content ([System.IO.Path]::Combine("${env:USERPROFILE}",'downloads','commits.json')) -Raw | ConvertFrom-Json | Select-object -ExpandProperty 'value'

    Write-Host "##[debug] commits found:" $commits.Count
    Write-Host ($commits | ConvertTo-Json | Out-String)

    return $commits
}

Function Get-PullRequestChanges{
    param(
        [Parameter(Mandatory=$false)]
        [string] $project = "${env:SYSTEM_TEAMPROJECT}"
    ,
        [Parameter(Mandatory=$false)]
        [string] $repositoryId = "${env:BUILD_REPOSITORY_NAME}"
    ,
        [Parameter(Mandatory=$false)]
        [string] $pullRequestId = "${env:BUILD_PULLREQUEST_ID}"
    )
    
    Write-Host "##[command] Get-PullRequestChanges"

    $commits = Get-PullRequestCommits

    ForEach ($commit in $commits){

        
    }
    return $commits
}