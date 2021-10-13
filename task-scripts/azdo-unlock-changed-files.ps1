#HEADER------------------------------------------------------------------------
$scriptPath="$env:SYSTEM_ARTIFACTSDIRECTORY"+"\infra"
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

#Get Git LFS Locks
$repo = [System.IO.Path]::Combine("${env:SYSTEM_ARTIFACTSDIRECTORY}","${env:BUILD_REPOSITORY_NAME}")

Set-GitRequestedForAuthExtraHeader

$splat = @{
    Path    = "$repo";
    Verbose = $VerbosePreference
}
$locks = (Get-LfsLocks @splat)

if ($null -eq $locks -Or $locks.count -eq 0){
    exit 0
}

if ("${env:BUILD_PULLREQUEST_ID}" -ne ""){
    #Get Pull Request Commits
    $commits = (Get-PullRequestCommits).commitId | Sort-Object -Unique
} else {
    $commits = "${env:BUILD_SOURCEVERSION}"
}

$changes = @()
ForEach ($commit in $commits){
    $splat = @{
        commitId    = "$commit";
        project     = "${env:SYSTEM_TEAMPROJECT}";
        repositoryId = "${env:BUILD_REPOSITORY_NAME}";
        Verbose     = $VerbosePreference
    }
    
    # Get Commit Changes
    $changes += (Get-CommitChanges @splat)
}

Write-Host "##[debug] checking changed files for locks"
$unlocks = @()
foreach ($change in $changes) {
    if ($change.changeType -eq 'edit' -and $change.item.gitObjectType -eq "blob") {

        $file = Convert-PathSeparators($change.item.path)

        Write-Host "##[debug] checking file for lock: $file"

        if($locks.Path -contains "$file" -and !($unlocks.Path -contains "$file")){

            Write-Host "##[debug] file locked: $file"
            $unlocks+=($locks | Where-Object -Property 'Path' -eq "$file")
        }
    }
}

# $files = ($files | Sort-Object -Unique)
Write-Host "##[debug] locks found on changed files:" $unlocks.count
Write-Host ($unlocks | ConvertTo-Json | Out-String)

If ($unlocks.count -gt 0){

    # $splat = @{
    #     userName    = "${env:RELEASE_REQUESTEDFOR}";
    #     userEmail   = "${env:RELEASE_REQUESTEDFOREMAIL}";
    #     Verbose     = $VerbosePreference
    # }
    # Set-GitUser @splat
    
    $splat = @{
        locks       = $unlocks;
        Verbose     = $VerbosePreference
    }
    Unlock-Lfs @splat

    
    
}

Set-GitOAuthExtraHeader