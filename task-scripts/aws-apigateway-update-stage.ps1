param(
        [Parameter(Mandatory=$true)] 
        [string] $apiId
    ,
        [Parameter(Mandatory=$true)] 
        [string] $setStage
    ,
        [Parameter(Mandatory=$false)]
        [string] $getStage = "latest"
    ,
        [Parameter(Mandatory=$false)]
        [string] $description = "AZDO Release.DeploymentId: ${env:RELEASE_DEPLOYMENTID}"
    )

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

Function Stringify() {
    param(
        [Parameter(Mandatory=$true)] 
        [string] $Value
    )

    $Value = $Value.replace('\','\\')
    $Value = $Value.replace('"','\"')

    $Value = $Value.replace("`r`n",'')
    $Value = $Value.replace("`t",'')
    $Value = $Value.replace(" ",'')

    # $Value = $Value.replace(']','\]')
    # $Value = $Value.replace('[','\[')
    # $Value = $Value.replace('}','\}')
    # $Value = $Value.replace('{','\{')

    return $Value
}


#Check API Id------------------------------------------------------------------------
try {
    $apiName = (aws apigateway get-rest-api --rest-api-id $apiId --query "name" --output text)
} catch {}
if($null -eq $apiName -Or "$apiName" -eq ""){
    Write-Host "##[error] -apiId not found: $apiId"
    exit 1
}

#Check VPC link------------------------------------------------------------------------
try {
    $nlbArn = (aws elbv2 describe-load-balancers --names "${setStage}-backend-nlb" --query "LoadBalancers[*].LoadBalancerArn" --output text)
    $vpcLinks = (aws apigateway get-vpc-links --output json | ConvertFrom-Json | Select-object -ExpandProperty 'items')
} catch {}
ForEach($vpcLink in $vpcLinks){
    if($vpcLink.targetArns.contains($nlbArn) -And ($vpcLink.Status -eq "AVAILABLE" -Or $vpcLink.Status -eq "PENDING")) {
        $vpcLinkId = $vpcLink.id
        break
    }
}

if($null -eq $vpcLinkId -Or "$vpcLinkId" -eq ""){
    Write-Host "##[debug] -vpcLinkId not found; creating one to: $nlbArn"

    add back in after test
    $vpcLink = ((aws apigateway create-vpc-link --name "${setStage}-VPCLink" --target-arns $nlbArn) | ConvertFrom-Json)
    $vpcLinkId = $vpcLink.id

    #update resource policy
    $json = [System.IO.Path]::Combine("${env:DEVOPS_CONFIGPATH}", "api-resource-policy.json")
    $json = (Get-Content "$json" | Out-String)
    $json =($ExecutionContext.InvokeCommand.ExpandString($json))

    $json = stringify($json)
    
    $json = "'" + $json + "'"
    $verifyApiId = (aws apigateway update-rest-api --rest-api-id $apiId --patch-operations op=replace,path=/policy,value=${json} --query "id" --output text)
    if("$apiId" -ne "$verifyApiId"){
        Write-Host "##[warning] resource policy not updated: $apiId"
    }
    
    #deploy resouce policy changes
    $description+=", update resource policy"
    $toDeploymentId = (aws apigateway create-deployment --rest-api-id $apiId --description $description --query 'id' --output text)
    
    if($null -eq $toDeploymentId -Or "$toDeploymentId" -eq "" ) {
        Write-Host "##[error] deployment failed: $description"
        exit 1
    }
}

Write-Host "##[debug] using -vpcLinkId: $vpcLinkId"
$Env:vpcLinkId = "$vpcLinkId"

#Get Deployment Id------------------------------------------------------------------------
if(!($null -eq $getStage -Or "$getStage" -like "latest" )) {
    Write-Host "##[debug] getting ${apiName}/${getStage} deployment: $deploymentId @ $createdDate"
    try {
        $toDeploymentId = (aws apigateway get-stage --rest-api-id $apiId  --stage-name "$getStage" --query "deploymentId" --output text)
    } catch {
        Write-Host "##[warning] getting ${apiName}/${getStage} deployment not found; using latest"
    }
}

if($null -eq $toDeploymentId -Or "$toDeploymentId" -eq "" ) {
    try {
        $deployments = (aws apigateway get-deployments --rest-api-id $apiId --output json | ConvertFrom-Json | Select-object -ExpandProperty 'items')
        $deployments | ForEach-Object {
            if ($null -eq $createdDate -Or $createdDate -lt $_.createdDate) {
                $toDeploymentId = $_.id
                $createdDate = $_.createdDate
            }
        }
    } catch {}
    Write-Host "##[debug] getting $apiName (latest) deployment: $toDeploymentId @ $createdDate"
}

#Create Stage------------------------------------------------------------------------
try {
    $fromDeploymentId = (aws apigateway get-stage --rest-api-id $apiId  --stage-name "$setStage" --query "deploymentId" --output text)
} catch {}
if($null -eq $fromDeploymentId -Or "$fromDeploymentId" -eq ""){
    Write-Host "##[debug] -setStage does not exist. Creating: $setStage"
    aws apigateway create-stage --rest-api-id $apiId --stage-name $setStage --deployment-id $toDeploymentId --tags "environment=$setStage"
}

#Update Deployment Description------------------------------------------------------------------------
if($null -eq $toDeploymentId -Or "$toDeploymentId" -eq ""){
    Write-Host "##[error] Deployemnt not found."
    exit 1
}elseif ($null -ne $description -And "$description" -ne "null") {
    Write-Host "##[debug] update $apiName ($deploymentId) description to: $description"
    $verifyDescription=(aws apigateway update-deployment --rest-api-id $apiId --deployment-id $toDeploymentId --patch-operations op=replace,path=/description,value="$description" --query "description" --output text)
    if (("$verifyDescription").Trim() -ne ("$description").Trim()) {
        Write-Host "##[warning] update $apiName ($deploymentId) description unsuccessful: $verifyDescription"
    }
}

#Update Stage Deployment------------------------------------------------------------------------
if($null -eq $toDeploymentId -Or "$toDeploymentId" -eq ""){
    Write-Host "##[error] -getStage not found: $getStage"
    exit 1
}elseif("$fromDeploymentId" -ne "$toDeploymentId"){
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

#Update Stage Variables------------------------------------------------------------------------
$splat = @{
    sourceCsv   = [System.IO.Path]::Combine("${env:DEVOPS_CONFIGPATH}", "env.csv")
    filename    = "api-gateway";
    env         = "$setStage";
    debug       = $false;
}

$variables = Get-Env @splat
Write-Host "##[debug] updating variables: $variables"

foreach ($variable in $variables) {
    $key = $variable.key
    $value = $variable.value

    $verifyVariables=(aws apigateway update-stage --rest-api-id $apiId --stage-name $setStage --patch-operations op=replace,path=/variables/$key,value=$value --query "variables.$key" --output text)
    if(!("$verifyVariables" -like "$value")){
        Write-Host "##[warning] variable not updated. $key = $verifyVariable"
    }
}

exit $LASTEXITCODE 