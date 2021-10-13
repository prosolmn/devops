param(
    [Parameter(Mandatory=$false)] 
    # [ValidateScript({Test-Path $_ -PathType 'Leaf'})]
    [string]  $outFile = "\\us.wmgi.com\root\Shared\DevOps\machines.csv"
)

$outarray = @()

$outarray += New-Object PsObject -property @{
    'ComputerName' = [System.Environment]::GetEnvironmentVariable('COMPUTERNAME')
    'LogonServer' = [System.Environment]::GetEnvironmentVariable('LOGONSERVER')
    'OS' = [System.Environment]::GetEnvironmentVariable('OS')
    'Platform' = [System.Environment]::OSVersion.Platform
    'ServicePack' = [System.Environment]::OSVersion.ServicePack
    'Version'= [System.Environment]::OSVersion.Version.Major, [System.Environment]::OSVersion.Version.Minor, [System.Environment]::OSVersion.Version.Build, [System.Environment]::OSVersion.Version.Revision -join "."
    'VersionString'= [System.Environment]::OSVersion.VersionString
    'Processor' = [System.Environment]::GetEnvironmentVariable('PROCESSOR_IDENTIFIER')
    'SpoolerStatus' = (Get-Service -Name Spooler).Status
}

$outProps = (
    'ComputerName',
    'LogonServer',
    'OS',
    'Platform',
    'ServicePack',
    'Version',
    'VersionString',
    'Processor',
    'SpoolerStatus'
)

$outarray | Select-Object -Property $outProps  | export-csv $outFile -NoTypeInformation -Append