Function Get-Library(){   
    param(
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)] 
        [string] $libraryName = '*'
    ,
        [Parameter(Mandatory=$false)]
        [string] $project = "$env:SYSTEM_TEAMPROJECT"
    )   

    if($null -eq $env:SYSTEM_ACCESSTOKEN){
        Write-Host "##[error] access the OAuth token through the System.AccessToken variable is disabled."
        exit 1
    }

    $header = @{ Authorization = "Bearer $env:SYSTEM_ACCESSTOKEN"}
    $url = "$env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI"+"$project"+'/_apis/distributedtask/variablegroups?api-version=6.0-preview.2'
    Write-Host "##[debug] url: $url"
    $libraries=(Invoke-WebRequest -Uri $url -method Get -Headers $header | ConvertFrom-Json | Select-object -ExpandProperty 'value')
    
    # debugging purposes
    # $libraries=(Get-Content "c:\users\nparadis\downloads\vars.json" | Out-String | ConvertFrom-Json | Select-object -ExpandProperty 'value')
    
    $outarray = @()
    
    foreach ($library in $libraries) {
        if ($library.Name -like $libraryName) {
            foreach($variable in $library.variables) {
                $library.variables.PSObject.Properties | ForEach-Object {
                    $isSecret = $false
                    if($null -ne $_.Value.value) {
                        $value=$_.Value.value
                    } elseif($_.Value.isSecret) {
                        $isSecret = $true
                        $value='****'
                    } else {
                        $value='(empty)'
                    }
    
                    $outArray+= New-Object PsObject -property @{
                        'libraryId'=$library.id
                        'libraryName'=$library.Name
                        'variableName'=$_.Name
                        'isSecret'=$isSecret
                        'variableValue'=$value
                    }
                }
            }
        }
    }

    return $outarray
}

Function Set-Library-Env(){   
    param(
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)] 
        [string] $libraryName
    ,
        [Parameter(Mandatory=$false)]
        [string] $project = "$env:SYSTEM_TEAMPROJECT"
    ,
        [Parameter(Mandatory=$false)]
        [bool] $overwrite = $true
    )

    $splat = @{
        libraryName = "$libraryName";
        project     = "$project"
    }
    $library=Get-Library @splat
    
    foreach ($var in $library) {
        if (! $var.isSecret -and $var.variableValue -ne ""){
            
            $splat = @{
                varName = $var.variableName;
                varValue = $var.variableValue;
                overwrite = $overwrite
            }

            Set-Env @splat
        }
    }

    $splat = @{
        varName = "${libraryName}_ISSET";
        varValue = $true;
        overwrite = $overwrite
    }
    Set-Env @splat
}