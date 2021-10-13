
Function Invoke-Lambda() {
    param(
        [Parameter(Mandatory=$true)] 
        [string] $functionName
    ,
        [Parameter(Mandatory=$false)]
        [string] $alias = '$LATEST'
    ,
        [Parameter(Mandatory=$true)] 
        [string] $payload
    )

    $guid=[System.Guid]::NewGuid().ToString("N")
    $targetFolder=[System.IO.Path]::GetTempPath()
    $outfile="${targetFolder}${guid}.json"

    $blob = ($payload | ConvertTo-Blob)

    Write-Host "##[debug] invoke ${functionName}:${alias}"
    $response = (aws lambda invoke --function-name "$functionName" --payload "$blob" "$outfile" --output json | ConvertFrom-Json)

    if ($response.StatusCode -ne 200){
        $response = ($response | ConvertTo-Json)
        Write-Host "##[error] $response"
        exit 1
    } else {
        Write-Host "##[debug] invokation successful." 
    }
}

Function Update-LambdaVariables(){
    param(
        [Parameter(Mandatory=$true)] 
        [string] $functionName
    ,
        [Parameter(Mandatory=$true)]
        [string] $env
    )

    $splat = @{
        filename    = "$functionName";
        env         = "$env";
    }

    $variables = Get-Env @splat
    If (!($null -eq $variables -Or "$variables" -eq "")){
        foreach ($variable in $variables) {
            $environment = environment + """" + $variable.key + """=""" + $variable.value + ""","
        }
        $environment = $environment -replace ".$"
        $environment = "Variables={"+$environment+"}"
        Write-Host "##[debug] "(aws lambda update-function-configuration --function-name $functionName --environment $environment)
    }

}