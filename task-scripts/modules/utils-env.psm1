<#
    .DESCRIPTION
    Prints parent script Name and supplied parameters. Sets AWS-specific environment variables.
    .OUTPUTS
    Null
    .EXAMPLE
    Write-Header -scriptPath "$PSCommandPath" -scriptArgs $args
#>
Function Write-Header(){
    param
    (
        [Parameter(Mandatory=$false)] 
        # [ValidateScript({Test-Path $_ -PathType 'Leaf'})]
        [string] # path to parent script for which to print details
        $scriptPath
    )
    Process {
        if (!(Test-Path "$env:DEVOPS_CONFIGPATH" -PathType 'Container')){
            $configPath = ([System.IO.Path]::Combine("${env:BUILD_SOURCESDIRECTORY}",'infra','aws-config'))
            $splat = @{
                varName = 'devops.configPath';
                varValue = "$configPath"
            }
            Set-Env $splat
        }

        if($null -eq $env:SYSTEM_ACCESSTOKEN){
            Write-Host "##[info] access to the OAuth token through the System.AccessToken variable is disabled."
        }

        if ($null -ne $env:ENVLIBRARY){
            if ($null -eq [System.Environment]::GetEnvironmentVariable("${env:ENVLIBRARY}_ISSET") -or !([System.Environment]::GetEnvironmentVariable("${env:ENVLIBRARY}_ISSET"))){
                Write-Host "##[section] Set env:ENVLIBRARY"
                $splat = @{
                    libraryName = "$env:ENVLIBRARY";
                    project     = "$env:SYSTEM_TEAMPROJECT"
                    overwrite   = $false
                }
                
                Set-Library-Env @splat
            }   
        }

        Write-Host "##[command] "(Split-Path $scriptPath -leaf)

        Write-Host "##[section] Parameters"
        
        $params = (Get-Command -Name ${scriptPath}).Parameters
        foreach ($key in $params.Keys) {
            $value = (Get-Variable $key -ErrorAction SilentlyContinue).Value
            try{
                if("$value" -like '*$(*)*'){
                    $value = ("$value" -replace '\$\((.+?)\)', '${$1}')
                    Write-Host "##[command] ${key} = ExpandString(${value})"
                    $value = $ExecutionContext.InvokeCommand.ExpandString("$value")
                    Set-Variable -Name "$key" -Value ($value) -Force -Scope global
                    Write-Host "##vso[task.setvariable variable=$key;]$value"
                }
            }catch{}

            $value = (Get-Variable $key -ErrorAction SilentlyContinue).Value
            Write-Host ("$key = $value")
        }

        Write-Host "##[section] Process"
    }
}

<#
    .DESCRIPTION
    Gets variable name and value from csv file
    .OUTPUTS
    PsObject of variables {key, value, filename}
#>
Function Get-Env(){
    param
    (
        [Parameter(Mandatory=$true)] 
        [string] 
        $filename
    ,
        [Parameter(Mandatory=$true)] 
        [string] 
        $env
    ,
        [Parameter(Mandatory=$false)] 
        [string] 
        $sourceCsv = [System.IO.Path]::Combine("${env:DEVOPS_CONFIGPATH}",'env.csv')
    )

    Process {

        try{
            $csv = import-csv $sourceCsv
        }catch{
            Write-Host ("##[error] $_.ScriptStackTrace")
            Write-Host ("##[error] $_")
        }

        If ($null -eq $csv){
            return $null
            exit 1
        }

        $variables = @()
        try{
            foreach($line in $csv) {  
                If($line.filename -like "$filename"){

                    $key = $line.var
    
                    If ($null -eq $line.$env -Or $line.$env -like ""){
                        $value = $line.default
                    }else{
                        $value = $line.$env
                    }
    
                    try {
                        $value = ($ExecutionContext.InvokeCommand.ExpandString($value))
                    } catch {
                        Write-Host ("##[error] $_.ScriptStackTrace")
                        Write-Host ("##[error] $_")
                    }
                    
                    if ("$value" -ne ""){
                        $variables += New-Object PsObject -property @{
                            key=$key
                            value=$value
                            filename=$line.filename
                        }
                    }
                }
            }
        }catch{
            Write-Host ("##[error] $_.ScriptStackTrace")
            Write-Host ("##[error] $_")
        }
        
        return $variables
    }
}

<#
    .DESCRIPTION
    Sets value of environment variable and pipeline variable
    .OUTPUTS
    Null
#>
Function Set-Env(){   
    param(
        [Parameter(Mandatory=$true)] 
        [string] $varName
    ,
        [Parameter(Mandatory=$true)]
        [string] $varValue
    ,
        [Parameter(Mandatory=$false)]
        [bool] $overwrite = $true
    ,
        [Parameter(Mandatory=$false)]
        [System.EnvironmentVariableTarget] $envScope = [System.EnvironmentVariableTarget]::User
    )

    Write-Host "##[debug] set variable $varName = $varValue"
    Write-Host "##vso[task.setvariable variable=$varName;]$varValue"
    Set-Variable -Name "$varName" -Value ($varValue) -Force -Scope global

    $envName = ($varName).Replace(".","_").toUpper()
    if ($null -eq [System.Environment]::GetEnvironmentVariable($envName,$envScope) -or $overwrite){
        [System.Environment]::SetEnvironmentVariable($envName,$varValue,$envScope)
        $varName = "env:${envName}"
        $command = "`$${varName} = `'$varValue`'"
        Write-Host "##[debug] set variable $varName = $varValue"
        Invoke-Expression -Command $command
        # Write-Host "##vso[task.setvariable variable=${varName};]${varValue}"
    }
}