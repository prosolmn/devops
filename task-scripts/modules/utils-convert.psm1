<#
    .DESCRIPTION
    Converts string into escaped string.
    .OUTPUTS
    Value
    .EXAMPLE
    Stringify -Value "$json"
#>
Function Stringify() {
    param(
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)] 
        [string] # String to escape
        $Value
    )

    $Value = $Value.replace('\','\\')
    $Value = $Value.replace('"','\"')

    $Value = $Value.replace("`r`n",'')
    $Value = $Value.replace("`t",'')
    $Value = $Value.replace(" ",'')

    return $Value
}

<#
    .DESCRIPTION
    Converts string into Blob.
    .OUTPUTS
    Value
    .EXAMPLE
    ConvertTo-Blob -Value "$json"
#>
Function ConvertTo-Blob(){
    param(
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)] 
        [string] # String to Blob
        $Value
    )
    
    $blob = "$Value"
    $blob = [System.Text.Encoding]::UTF8.GetBytes($blob)
    $blob = [System.Convert]::ToBase64String($blob)

    return $blob
}

<#
    .DESCRIPTION
    replaces illegal characters in string
    .OUTPUTS
    string
#>
Function ConvertTo-Filename(){
    param(
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)] 
        [string]
        $Value
    ,
        [Parameter(Mandatory=$false)] 
        [string] # illegal character replacement
        $Replace = '_'
    )

    return $Value.Split([IO.Path]::GetInvalidFileNameChars()) -join "$Replace"
}

<#
    .DESCRIPTION
    replaces any path seperators with consistent separator characture 
    .OUTPUTS
    string
#>
Function Convert-PathSeparators{
    param(
        [Parameter(ValueFromPipeline=$true,Mandatory=$true)] 
        [string] $Path
    ,
        [Parameter(Mandatory=$false)] 
        [string] $Char = [System.IO.Path]::DirectorySeparatorChar
    )
        $Path = $Path.Replace('/',"$Char")
        $Path = $Path.Replace('\',"$Char")
    
        return $Path
}


Function Unmask() {
    param(
        [Parameter(ValueFromPipeline=$true,Mandatory=$true)] 
        [string] $Value
    )

    $Bytes = [System.Text.Encoding]::Unicode.GetBytes($Value)
    $EncodedText =[Convert]::ToBase64String($Bytes)
    Write-Host "##[debug] EncodedText: $EncodedText"
    $DecodedText = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($EncodedText))
    
    return $DecodedText
}