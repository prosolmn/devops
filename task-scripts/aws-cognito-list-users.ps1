param(
    [Parameter(Mandatory=$true)] 
    [string] $cognitoPoolId
,
    [Parameter(Mandatory=$false)] 
    # [ValidateScript({Test-Path $_ -PathType 'Leaf'})]
    [string]  $outFile = [System.IO.Path]::Combine("${env:AGENT_TEMPDIRECTORY}", 'cognito-users.csv')
)

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

Function GetAttribute(){
    param(
        [Parameter(Mandatory=$true)] 
        [psobject] $object
    ,
        [Parameter(Mandatory=$true)] 
        [string] $attribute
    )

    $value = ($object.Attributes | where { $_.Name -eq "$attribute" } | Select -ExpandProperty Value)

    return $value
}

$outarray = @()

$cognitoUsers = (aws cognito-idp list-users --user-pool-id "$cognitoPoolId" --query "Users[*]" --output json | ConvertFrom-Json)

$cognitoUsers | ForEach-Object {
    $outarray += New-Object PsObject -property @{
        'Email' = GetAttribute -object $_ -attribute 'email'
        'Role' = GetAttribute -object $_ -attribute 'custom:role'
        'GivenName' = GetAttribute -object $_ -attribute 'given_name'
        'FamilyName' = GetAttribute -object $_ -attribute 'family_name'
        'CenterName' = GetAttribute -object $_ -attribute 'custom:centerName'
        'City'= GetAttribute -object $_ -attribute 'custom:city'
        'State'= GetAttribute -object $_ -attribute 'custom:state'
        'ZipCode'= GetAttribute -object $_ -attribute 'custom:zipCode'
        'CreateDate'= $_.UserCreateDate.Substring(0,10) + " " + $_.UserCreateDate.Substring(11,8)
        'LastModifiedDate'= $_.UserLastModifiedDate.Substring(0,10) + " " + $_.UserLastModifiedDate.Substring(11,8)
        'Enabled'= $_.Enabled
        'Status'= $_.UserStatus
        'Locale' = GetAttribute -object $_ -attribute 'locale'
        'pcmsUserGUID' = GetAttribute -object $_ -attribute 'custom:pcmsUserGUID'
    }
}

$outProps = (
    'Email', 
    'Role', 
    'GivenName', 
    'FamilyName', 
    'CenterName', 
    'City', 
    'State', 
    'ZipCode', 
    'CreateDate', 
    'LastModifiedDate', 
    'Enabled', 
    'Status', 
    'Locale', 
    'pcmsUserGUID'
)

$outarray | Select-Object -Property $outProps  | export-csv $outFile -NoTypeInformation