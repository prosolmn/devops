Function Update-ApiGateway(){
    param(
        [Parameter(Mandatory=$true)] 
        [string] $apiId
    ,
        [Parameter(Mandatory=$false)] 
        [string] $stageName = "${env:STAGENAME}"
    ,
        [Parameter(Mandatory=$true)] 
        [ValidateScript({Test-Path ([System.IO.Path]::Combine("${env:DEVOPS_CONFIGPATH}", $_)) -PathType 'Leaf'})]
        [string] $sourceJson
    ,
        [Parameter(Mandatory=$false)]
        [string] $targetFolder = [System.IO.Path]::GetTempPath()
    ,
        [Parameter(Mandatory=$false)]
        [string] $description = "AZDO Release.DeploymentId: ${env:RELEASE_DEPLOYMENTID}"
    )

    #set vpcEndpointId variable
    # $vpcEndpointId = (Get-VpcEndpointId -vpcId "${env:AWS_VPCID}")
    # Set-Env -varName 'aws.vpcEndpointId' -varValue "$vpcEndpointId"

    #update template variables
    $json = [System.IO.Path]::Combine("${env:DEVOPS_CONFIGPATH}", "$sourceJson")
    $json = (Get-Content "$json" | Out-String)
    $json = $json.replace('${stageVariables.','{stageVariables.')
    $json = $ExecutionContext.InvokeCommand.ExpandString($json)
    $json = $json.replace('{stageVariables.','${stageVariables.')
    $json = ($json | ConvertTo-Blob)

    $targetJson = [System.IO.Path]::Combine("${targetFolder}", "${stageName}-${sourceJson}")

    #write blob to file
    if(Test-Path $targetJson -PathType 'Leaf'){
        Clear-Content -Path $targetJson -Force
    }
    Add-Content -Path $targetJson -Value $json -Force
    
    #import to aws apigateway
    $response = $(aws apigateway put-rest-api --rest-api-id "$apiId" --body "file://${targetJson}" --fail-on-warnings --mode overwrite --output json | ConvertFrom-Json)
    
    if ($response.id -eq "$apiId"){
        Write-Host "##[info] apigateway import-rest-api for ${apiId}: successful"
    }else {
        Write-Host "##[error] apigateway import-rest-api for ${apiId}: unsuccessful"
        Write-Host ($response | ConvertTo-Json)
        exit 1
    }
    
    #deploy to stage
    $deploymentId = (aws apigateway create-deployment --rest-api-id $apiId --stage-name "$stageName" --stage-description "Prophecy Portal API $stageName stage" --query 'id')
    
    $splat = @{
        apiId       = $apiId;
        deploymentId   = $deploymentId
        description = "$description"
    }

    Update-ApiDeploymentDescription @splat

    $splat = @{
        apiId       = "$apiId";
        stageName   = "$stageName"
    }

    #update stage variables
    Update-ApiStageVariables @splat

    return $deploymentId
}

Function Update-ApiStageVariables(){
    param(
        [Parameter(Mandatory=$true)] 
        [string] $apiId
    ,
        [Parameter(Mandatory=$true)] 
        [string] $stageName
    )

    $vpcLinkId = (Get-VpcLinkId)
    Set-Env -varName 'aws.vpcLinkId' -varValue "$vpcLinkId"

    $splat = @{
        sourceCsv   = [System.IO.Path]::Combine("${env:DEVOPS_CONFIGPATH}", 'env.csv');
        filename    = "api-gateway";
        env         = "$stageName";
        debug       = $false;
    }
    
    $variables = Get-Env @splat
    Write-Host "##[debug] updating variables: "( $variables | ConvertTo-Json)
    
    foreach ($variable in $variables) {
        $key = $variable.key
        $value = $variable.value
    
        $verifyVariables=(aws apigateway update-stage --rest-api-id $apiId --stage-name $stageName --patch-operations op=replace,path=/variables/$key,value=$value --query "variables.$key" --output text)
        if(!("$verifyVariables" -like "$value")){
            Write-Host "##[warning] variable not updated. $key = $verifyVariable"
        }
    }

}
Function Get-ApiName(){
    param(
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)] 
        [string] $apiId
    )

    try {
        $apiName = (aws apigateway get-rest-api --rest-api-id $apiId --query "name" --output text)
    } catch {}
    if($null -eq $apiName -Or "$apiName" -eq ""){
        Write-Host "##[error] -apiId not found: $apiId"
        exit 1
    }
    return $apiName
}

Function Get-VpcLinkId(){
    param(
        [Parameter(Mandatory=$false)] 
        [string] $vpcId = "${env:AWS_VPCID}"
    ,
        [Parameter(Mandatory=$false)] 
        [string] $env
    )

    try {
        $vpcLinks = (aws apigateway get-vpc-links --output json | ConvertFrom-Json | Select-object -ExpandProperty 'items')
    } catch {}

    if ($vpcId -eq ""){
        $nlb = (aws elbv2 describe-load-balancers --names "${env}-backend-nlb" --query "LoadBalancers[*]" --output text)
    }else {
        $elbs = (aws elbv2 describe-load-balancers --query "LoadBalancers[*]" --output json | ConvertFrom-Json)
        ForEach($elb in $elbs){
            if($elb.vpcId -eq $vpcId -And $elb.Scheme -eq "Internal") {
                $nlb = $elb
                break
            }
        }   
    }

    ForEach($vpcLink in $vpcLinks){
        if($vpcLink.targetArns.contains($nlb.LoadBalancerArn) -And ($vpcLink.Status -eq "AVAILABLE" -Or $vpcLink.Status -eq "PENDING")) {
            $vpcLinkId = $vpcLink.id
            break
        }
    }
    
    if($null -eq $vpcLinkId -Or "$vpcLinkId" -eq ""){
        Write-Host "##[debug] -vpcLinkId not found; creating one to: $nlbArn"
        $vpcLinkName = $nlb.LoadBalancerName + "-VPCLink"
        $vpcLink = ((aws apigateway create-vpc-link --name "$vpcLinkName" --target-arns $nlb.LoadBalancerArn) | ConvertFrom-Json)
    }

    Write-Host "##[debug] -vpcLink:" $vpcLink.name "(${vpcLinkId})"

    return $vpcLink.Id
}

Function Get-VpcEndpointId(){
    param(
        [Parameter(Mandatory=$false)] 
        [string] $vpcId = "${env:AWS_VPCID}"
    ,
        [Parameter(Mandatory=$false)] 
        [string] $serviceName
    )

    try {
        $vpcEndPoints = (aws ec2 describe-vpc-endpoints --query "VpcEndpoints[]" --output json | ConvertFrom-Json)
    } catch {}

    
    ForEach($vpce in $vpcEndPoints){
        if($vpce.VpcId -eq "$vpcId" -And $vpce.ServiceName -like "*.execute-api") {
            $vpcEndpointId = $vpce.VpcEndpointId
            break
        }
    }
    
    Write-Host "##[debug] -vpcEndpointId: $vpcEndpointId"
    return $vpcEndpointId
}

Function Update-ApiResourcePolicy(){
    param(
        [Parameter(Mandatory=$true)] 
        [string] $apiId
    ,
        [Parameter(Mandatory=$false)] 
        [string] $stageName
    )
    
    $json = [System.IO.Path]::Combine("${env:DEVOPS_CONFIGPATH}", 'api-resource-policy.json');
    $json = (Get-Content "$json" | Out-String)
    $json =($ExecutionContext.InvokeCommand.ExpandString($json))
    
    $json = stringify($json)
    
    $json = "'" + $json + "'"
    $verifyApiId = (aws apigateway update-rest-api --rest-api-id $apiId --patch-operations op=replace,path=/policy,value=${json} --query "id" --output text)
    if("$apiId" -ne "$verifyApiId"){
        Write-Host "##[warning] resource policy not updated: $apiId"
    }
    
    #deploy resouce policy changes
    $description+="AZDO Release.DeploymentId: ${env:RELEASE_DEPLOYMENTID} & update resource policy"
    if ($null -eq $stageName -Or "$stageName" -eq ""){
        $toDeploymentId = (aws apigateway create-deployment --rest-api-id $apiId --description $description --query 'id' --output text)
    }else{
        $toDeploymentId = (aws apigateway create-deployment --rest-api-id $apiId --stage-name "$stageName" --description $description --query 'id' --output text)
    }
    
    return $toDeploymentId
}
Function Get-ApiDeploymentId(){
    param(
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)] 
        [string] $apiId
    ,
        [Parameter(Mandatory=$false)]
        [string] $stageName = "latest"
    )

    Write-Host "##[debug] getting ${apiId}/${getStage} deployment"
    if(!("$getStage" -like "latest" )) {
        try {
            $deploymentId = (aws apigateway get-stage --rest-api-id $apiId  --stage-name "$stageName" --query "deploymentId" --output text)
        } catch {
            Write-Host "##[warning] deployment for `'${stageName}`' not found; using latest"
        }
    }

    if($null -eq $deploymentId -Or "$deploymentId" -eq "" ) {
        try {
            $deployments = (aws apigateway get-deployments --rest-api-id $apiId --output json | ConvertFrom-Json | Select-object -ExpandProperty 'items')
            $deployments | ForEach-Object {
                if ($null -eq $createdDate -Or $createdDate -lt $_.createdDate) {
                    $deploymentId = $_.id
                    $createdDate = $_.createdDate
                }
            }
        } catch {}
    }
    Write-Host "##[debug] getting ${apiId}/${getStage} deployment: $deploymentId"

    return $deploymentId
}
Function Add-ApiStage(){
    param(
        [Parameter(Mandatory=$true)] 
        [string] $apiId
    ,
        [Parameter(Mandatory=$true)]
        [string] $stageName
    )

    try {
        $deploymentId = (aws apigateway get-stage --rest-api-id $apiId  --stage-name "$stageName" --query "deploymentId" --output text)
    } catch {}
    if($null -eq $deploymentId -Or "$deploymentId" -eq ""){
        $deploymentId = Get-ApiDeploymentId -apiId $apiId
        Write-Host "##[debug] -stage does not exist. Creating: $stageName"
        aws apigateway create-stage --rest-api-id $apiId --stage-name $stageName --deployment-id $deploymentId --tags "environment=$setStage"
    }
    return $deploymentId
}

Function Update-ApiDeploymentDescription(){
    param(
        [Parameter(Mandatory=$true)] 
        [string] $apiId
    ,
        [Parameter(Mandatory=$true)]
        [string] $deploymentId
    ,
        [Parameter(Mandatory=$true)]
        [string] $description
    )

    Write-Host "##[debug] update $apiName ($deploymentId) description to: $description"
    $verifyDescription=(aws apigateway update-deployment --rest-api-id $apiId --deployment-id $deploymentId --patch-operations op=replace,path=/description,value="$description" --query "description" --output text)
    if (("$verifyDescription").Trim() -ne ("$description").Trim()) {
        Write-Host "##[warning] update $apiName ($deploymentId) description unsuccessful: $verifyDescription"
        exit 1
    }
}

Function Update-ApiStageDeployment(){
    param(
        [Parameter(Mandatory=$true)] 
        [string] $apiId
    ,
        [Parameter(Mandatory=$true)]
        [string] $stageName
    ,
        [Parameter(Mandatory=$true)]
        [string] $deploymentId
    )

    $fromDeploymentId = Get-ApiDeploymentId -apiId $apiId -stageName "$stageName"

    if("$fromDeploymentId" -ne "$toDeploymentId"){
        Write-Host "##[command] Update API Gateway: $apiName Stage: $setStage deployment to: $toDeploymentId"
        $verifyDeploymentId=(aws apigateway update-stage --rest-api-id $apiId --stage-name $setStage --patch-operations op=replace,path=/deploymentId,value=$toDeploymentId --query "deploymentId" --output text)
    
        if ("$verifyDeploymentId" -like "$toDeploymentId"){
            Write-Host "##[info] Update API Gateway: $apiName/$setStage update deployment to: $verifyDeploymentId successful."
        }else{
            Write-Host "##[error] Update API Gateway: $apiName/$setStage update deployment to: $verifyDeploymentId unsuccessful."
            exit 1
        }
    }else{
        Write-Host "##[info] Update API Gateway: $apiName Stage: $setStage already deployed to: $fromDeploymentId"
    }
}