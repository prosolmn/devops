Function Get-GitOAuth(){
    
    Write-Host "##[command] Get-GitOAuthExtraHeader"
    
    If ("${env:SYSTEM_ACCESSTOKEN}" -eq ""){
        Write-Host "##[warning] access to the OAuth token through the System.AccessToken variable is disabled."
    } else {
        $authHeader="Authorization: bearer ${env:SYSTEM_ACCESSTOKEN}"
        return $authHeader
    }
    
}

Function Get-GitExtraHeader(){
    
    If("${env:BUILD_REPOSITORY_URI}" -ne ""){
        $extraHeader="http.${env:BUILD_REPOSITORY_URI}.extraheader"
    }else{
        $extraHeader="http.extraheader"
    }
    
    Write-Host "##[command] Get-GitExtraHeader: $extraHeader"

    return $extraHeader
    
}

Function Set-GitOAuthExtraHeader(){    
    
    $authHeader = Get-GitOAuth
    if ("$authHeader" -ne ""){
        $extraHeader = Get-GitExtraHeader

        #Clear existing auth header
        Clear-GitRequestedForAuthExtraHeader

        Write-Host "##[command] Set-GitOAuthExtraHeader: git config ${extraHeader}"
        git config "${extraHeader}" "${authHeader}"
    }
    
}

Function Clear-GitOAuthExtraHeader(){
    
    $extraHeader = Get-GitExtraHeader

    Write-Host "##[command] Clear-GitOAuthExtraHeader: git config --unset-all ${extraheader}"
    git config --unset-all "${extraheader}"
    
}

Function Get-GitRequestedForAuth(){
    param(
        [Parameter(Mandatory=$false)] 
        [string] $userEmail = "${env:RELEASE_REQUESTEDFOREMAIL}"
    )    
    Write-Host "##[command] Get-GitRequestedForAuth: $userEmail"

    #try to get env variable for PAT of requested for user
    $userName = $userEmail.Split('@')[0]
    $envName = '$env:'+("${userName}.gitPAT").Replace(".","_").toUpper()
    $MyPat = ($ExecutionContext.InvokeCommand.ExpandString($envName))  
    

    #set new auth header
    if ("$MyPat" -eq ""){
        Write-Host "##[warning] value not found for: $envName"
    }else{
        $B64Pat = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":${MyPat}"))
        $auth = "Authorization: Basic $B64Pat"

        Write-Host "##[debug] GitRequestedForAuth: Authorization: Basic: ****"
        return $auth
    }
}

Function Set-GitRequestedForAuthExtraHeader(){
    
    $authHeader = Get-GitRequestedForAuth
    if ("$authHeader" -ne ""){

        #Clear existing auth header
        Clear-GitOAuthExtraHeader

        Write-Host "##[command] Set-GitRequestedForAuthExtraHeader: git config http.extraheader"
        
        git config http.extraheader "${authHeader}"
    }
    if ("${env:RELEASE_REQUESTEDFOR}" -ne ""){   
        Write-Host "##[command] Set-GitRequestedForAuthExtraHeader: git config user.name ${env:RELEASE_REQUESTEDFOR}"
        git config user.name "${env:RELEASE_REQUESTEDFOR}" 
    }
    if ("${env:RELEASE_REQUESTEDFOREMAIL}" -ne ""){   
        Write-Host "##[command] Set-GitRequestedForAuthExtraHeader: git config user.email ${env:RELEASE_REQUESTEDFOREMAIL}"
        git config user.email "${env:RELEASE_REQUESTEDFOREMAIL}"
    }
}

Function Clear-GitRequestedForAuthExtraHeader(){
    
    Write-Host "##[command] Clear-GitRequestedForAuthExtraHeader: git config --unset-all http.extraheader"
    git config --unset-all http.extraheader
    Write-Host "##[command] Clear-GitRequestedForAuthExtraHeader: git config --unset-all user.name"
    git config --unset-all "user.name"
    Write-Host "##[command] Clear-GitRequestedForAuthExtraHeader: git config --unset-all user.email"
    git config --unset-all "user.email"

}

Function Get-LfsLocks{
    param(
        [Parameter(ValueFromPipeline=$true, Mandatory=$false)] 
        [string] $Path = [System.IO.Path]::Combine("${env:SYSTEM_ARTIFACTSDIRECTORY}","${env:BUILD_REPOSITORY_NAME}")
    )

    Write-Host "##[command] Get-LfsLocks"

    $tab = [char]9

    $locks = @()

    if (Test-Path "$Path" -PathType Container){
        Write-Host "##[debug] setting location: $Path"
        Set-Location -Path "$Path"
    }else{
        $Path = Get-Location
    }

    Write-Host "##[command] getting LFS locks: $Path"
    $lfsLocks = (git lfs locks)

    foreach ($lfsLock in $lfsLocks){
        $locks += [pscustomobject]@{
            Path = (Convert-PathSeparators('/' + ($lfsLock.Split($tab))[0])).Trim()
            User = (($lfsLock.Split($tab))[1]).Trim()
            ID = ((($lfsLock.Split($tab))[2]).Split(':')[1]).Trim()
        }
    }

    Write-Host "##[debug] LFS locks found:" $locks.Count
    Write-Host ($locks | ConvertTo-Json | Out-String)
    
    return $locks
}

Function Unlock-Lfs {
    param(
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)] 
        [pscustomobject[]] $locks
    ,
        [Parameter(Mandatory=$false)] 
        [string] $Path = [System.IO.Path]::Combine("${env:SYSTEM_ARTIFACTSDIRECTORY}","${env:BUILD_REPOSITORY_NAME}")
    )
   
    Write-Host "##[command] Unlock-Lfs"

    ForEach ($lock in $locks){
        Write-Host "##[debug] unlocking file:" $lock.Path
        $ID = $lock.ID

        git lfs unlock -i "$ID" -f            
    }
    
    # Get New list of locks and verify old list not on new list
    $splat = @{
        Path    = "$Path";
        Verbose = $VerbosePreference
    }
    $newLocks = (Get-LfsLocks @splat)
    $count = 0
    ForEach ($lock in $locks){
        if($newLocks.Path -contains $lock.Path){
            Write-Host "##[warning] file unlocked FAILED:" $lock.Path
        } else {
            $count += 1
        }
    }

    Write-Host "##[debug] unlocked files: $count"
}

Function Lock-Lfs {
    param(
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)] 
        [string[]] $Paths
    )

    Write-Host "##[command] Lock-Lfs"

    $count = 0
    ForEach ($Path in $Paths){
        Write-Host "##[debug] locking file: $Path"
        try {
            git lfs lock "$Path"
            $count += 1
        }catch{}
    }

    Write-Host "##[debug] locked files:" $count
}

# Function Get-GitLfsUri(){
#     param(
#         [Parameter(Mandatory=$false)]
#         [string] $userEmail = "${env:RELEASE_REQUESTEDFOREMAIL}"
#     ,
#         [Parameter(Mandatory=$false)]
#         [string] $repositoryUri = "${env:BUILD_REPOSITORY_URI}"
#     )

#     Write-Host "##[command] Get-GitLfsUrl"

#     $userEmail = [System.Web.HTTPUtility]::UrlEncode("${userEmail}")
    
#     $oldUserUrl = $repositoryUri.split('/')[2] 
#     $user = $oldUserUrl.split('@')[0]
#     $newUserUrl = $oldUserUrl.Replace("$user","$userEmail")
#     # $newUserUrl = $oldUserUrl.Replace("$user","${env:SYSTEM_ACCESSTOKEN}")

#     $repositoryUri = $repositoryUri.Replace("$oldUserUrl","$newUserUrl")
#     $repositoryUri="${repositoryUri}/info/lfs/"

#     Write-Host "##[debug] repository URI: $repositoryUri"

#     return $repositoryUri
# }

# Function Get-GitUri(){
#     param(
#         [Parameter(Mandatory=$false)]
#         [string] $repositoryUri = "${env:BUILD_REPOSITORY_URI}"
#     )

#     Write-Host "##[command] Get-GitUri"

#     $http=$repositoryUri.split('/')[0] 
#     $uri = $repositoryUri.split('/')[2] 

#     $org = $uri.split('@')[0]

#     $newUri = $uri.Replace("$org","${org}:${env:SYSTEM_ACCESSTOKEN}")
#     # $gitUri="${http}//${newUri}"

#     $repositoryUri = $repositoryUri.Replace("$uri","$newUri")
#     $gitUri="${http}//${repositoryUri}"
    

#     Write-Host "##[debug] Git URI: $gitUri"

#     return $gitUri
# }