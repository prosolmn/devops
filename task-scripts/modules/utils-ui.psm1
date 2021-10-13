<#
    .DESCRIPTION
    Sets value of environment variable and pipeline variable
    .OUTPUTS
    Message Box Result
#>
Function MsgBox(){   
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)] 
        [string] $Prompt
    ,
        [Parameter(Mandatory=$false)] 
        [string] $Title
    ,
        [Parameter(Mandatory=$false)]
        $Buttons = 0 #[System.Windows.MessageBoxButton] https://docs.microsoft.com/en-us/dotnet/api/system.windows.messageboxbutton?redirectedfrom=MSDN&view=net-5.0
    ,
        [Parameter(Mandatory=$false)]
        $Icon = 0 #[System.Windows.MessageBoxImage] https://docs.microsoft.com/en-us/dotnet/api/system.windows.messageboximage?redirectedfrom=MSDN&view=net-5.0
    )

    Add-Type -AssemblyName PresentationCore,PresentationFramework
    $Result = ([System.Windows.MessageBox]::Show($Prompt,$Title,$Buttons,$Icon))
    
    return $Result
}


<#
    .DESCRIPTION
    get-enumValues -enum "System.Diagnostics.Eventing.Reader.StandardEventLevel"
    .OUTPUTS
    Enum Values
#>
Function Get-EnumValues(){
    Param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)] 
        [string]$enum
    )

    $enumValues = @{}
   
    [System.Enum]::GetValues([type]$enum) | ForEach-Object { 
        $enumValues.add($_, $_.value__)
    }

    $enumValues
}