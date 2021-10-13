param(
    [Parameter(Mandatory=$true)] 
    [string] $cognitoPoolId
,
    [Parameter(Mandatory=$true)] 
    [string]  $userEmail
,
    [Parameter(Mandatory=$false)] 
    [string]  $command = 'UPDATE'
,
    [Parameter(Mandatory=$false)] 
    [string]  $field
,
    [Parameter(Mandatory=$false)] 
    [string]  $value
)

#HEADER------------------------------------------------------------------------
$scriptPath=[System.IO.Path]::Combine("$env:SYSTEM_ARTIFACTSDIRECTORY", "infra")
if (!(test-path "$scriptPath" -PathType Container)){$scriptPath="."}
(Get-ChildItem -Path "$scriptPath" -Filter "*.psm1"  -Recurse).FullName | Import-Module -DisableNameChecking
Write-Header -scriptPath "$PSCommandPath"
#HEADER------------------------------------------------------------------------

$command = $command.ToUpper()
$cognitoUsers=(aws cognito-idp admin-get-user --user-pool-id $cognitoPoolId  --username $userEmail --query "Username" --output json | ConvertFrom-Json)

if ($null -eq $cognitoUsers) {
    Write-Host "##[error] no cognito user found in pool matching email."
    exit 1
}

foreach ($cognitoUser in $cognitoUsers){
    Write-Host "##[debug] $command cognito user: $cognitoUser"

    switch ( $command ) {
        'UPDATE' {
            Write-Host "##[debug] Set $field to $value"
            aws cognito-idp admin-update-user-attributes --user-pool-id $cognitoPoolId --username $cognitoUser --user-attributes Name="$field",Value="$value"
        } 
        'CONFIRM' {
            aws cognito-idp admin-confirm-sign-up --user-pool-id $cognitoPoolId --username $cognitoUser 
        } 
        'ENABLE' {
            aws cognito-idp admin-enable-user --user-pool-id $cognitoPoolId --username $cognitoUser
        } 
        'DISABLE' {
            aws cognito-idp admin-disable-user --user-pool-id $cognitoPoolId --username $cognitoUser
        } 
        'DELETE' {
            aws cognito-idp admin-disable-user --user-pool-id $cognitoPoolId --username $cognitoUser
            aws cognito-idp admin-delete-user --user-pool-id $cognitoPoolId --username $cognitoUser
        }
    }
    try {
        if ($command -ne 'DELETE') {
            aws cognito-idp admin-get-user --user-pool-id $cognitoPoolId  --username $cognitoUser
        }
    } catch {}
    
}