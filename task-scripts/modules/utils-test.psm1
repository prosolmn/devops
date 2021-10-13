<#
    .DESCRIPTION
    Calculates hash for a path or file
    .OUTPUTS
    Hash value
    .EXAMPLE
    Get-Hash -path ".\"
#>
Function Get-Hash (){
    param(
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)] 
        [ValidateScript({Test-Path $_})]
        [string] $path
    ,   
        [Parameter(Mandatory=$false)]
        [string] $algorithm = "SHA1"
    ,
        [Parameter(Mandatory=$false)] 
        [string] $include = "*"
    ,
        [Parameter(Mandatory=$false)] 
        [string] $exclude = ""
    ,
        [Parameter(Mandatory=$false)] 
        [string] $outFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), (ConvertTo-Filename -value "${path}")+".${algorithm}")
    )

    if (test-path $path -PathType Container){
        Write-Verbose "##[debug] -path found: $path"
        # $hashes=(Get-ChildItem "$path" -Force -File -Recurse | Sort-Object -Property Name | % {Get-FileHash -Algorithm "$algorithm" $_.FullName} |  %  {Write-Output (($_.Hash.ToLower())+","+$(Split-Path -path $_.Path -Leaf))})
        # $TempFile = New-TemporaryFile
        # $hashFile = $TempFile.FullName
        $hashFile = $outFile
        Write-Verbose "##[debug] writing file hashes to: $hashFile"

        $files = (Get-ChildItem "$path" -Force -File -Recurse | Where-Object {($_.FullName -like "$include") -And ($_.FullName -notLike "$exclude")} | Sort-Object -Property FullName)

        foreach ($file in $files) {
            $fileHash = (Get-FileHash -Algorithm "$algorithm" $file.FullName)
            $output = (($fileHash.algorithm)+":"+($fileHash.Hash.ToLower())+" "+(($fileHash.Path).Replace("$path",'.')))
            Write-Verbose "$output"
            Write-Output ($output) | Out-File -FilePath $hashFile -Append
        }

        Write-Host "##vso[task.uploadfile]$hashFile"
    }else{
        Write-Verbose "##[debug] -path is file: $path"
        $hashFile = "$path"
    }
        
    $hash = (Get-FileHash -Algorithm "$algorithm" -LiteralPath "$hashFile").Hash
    
    # if($null -ne $TempFile.FullName -And $TempFile.FullName -ne "" ) {
    #     Remove-Item $TempFile.FullName -Force
    # }

    if($null -eq $hash -Or $hash -eq ""){
        Write-Verbose "##[error] ${path}, ${algorithm}:error"
        return "$hash"
        exit 1
    }else{
        Write-Verbose "##[debug] ${path}, ${algorithm}:${hash}"
        return "$hash"
        exit 0
    }
}

<#
    .DESCRIPTION
    Writes Junit XML file from test results array
    .OUTPUTS
    Path to junit xml
    .EXAMPLE
    Get-Hash -path "."
#>
Function Write-JunitXml(){
    param(
        [Parameter(Mandatory=$true)] 
        [string] $fileName
    ,
        [Parameter(Mandatory=$true)]
        [string] $tgtPath = [System.IO.Path]::GetTempPath()
    ,
        [Parameter(Mandatory=$true)]
        [PSCustomObject] $results
    )

$template = @'
<?xml version="1.0" encoding="utf-8"?>
<testsuite name="" timestamp="" tests="" passed="" failures=""  skipped="" errors="" hostname="" file="">
    <testcase name="" result=""></testcase>
</testsuite>
'@

    $TempFile = New-TemporaryFile

    # $guid = [System.Guid]::NewGuid().ToString("N")
	# $templatePath = [System.IO.Path]::GetTempPath()+"${guid}.txt"

    $template | Out-File $TempFile -encoding UTF8 -Force
    If (Test-Path "$fileName" -PathType 'Leaf') {
        $testSuiteName = (Get-Item "$fileName").BaseName
    } else {
        $testSuiteName = $fileName
    }
	
    # load template into XML object
	$xml = New-Object xml
	$xml.Load($TempFile)

    $newTestCaseTemplate = $xml.testsuite.testcase.Clone()

    $xml.testsuite.name = "$testSuiteName"
    $xml.testsuite.hostname = "$env:COMPUTERNAME"
    $xml.testsuite.timestamp = (Get-Date).ToString()
    $xml.testsuite.file = "$fileName"
    
    [int]$tests=0
    [int]$passed=0
    [int]$failures=0
    [int]$skipped=0
    [int]$errors=0

    foreach($result in $results) {
        $tests++
        
        $resultName = ($result.Name).ToString()+"_"+('{0:d3}' -f $tests)
        $resultVal = ($result.Result).ToString()
        $resultMsg = ($result.Message)

        $newTestCase = $newTestCaseTemplate.clone()
        $newTestCase.name = "$resultName"
        $newTestCase.result = "$resultVal"
        $xml.testsuite.AppendChild($newTestCase) | Out-Null
        #$xml.testsuite.testcase.AppendChild($xml.CreateElement($result[0],$null)) | Out-Null
        
        $resultXml = $xml.CreateElement($resultVal,$null)
        if ($null -ne $resultMsg){
            $resultXml.SetAttribute("message",$resultMsg)
        }
        $xml.testsuite.testcase.AppendChild($resultXml) | Out-Null

        switch ($resultVal) { 
              "failure" { 
                $failures++ 
                Break
            } "passed" {
                $passed++
                Break
            } "skipped" {
                $skipped++
                Break
            } Default {
                $errors++
                Break
            }
        }
    }

    $xml.testsuite.tests = "$tests"
    $xml.testsuite.passed = "$passed"
    $xml.testsuite.failures = "$failures"
    $xml.testsuite.skipped = "$skipped"
    $xml.testsuite.errors = "$errors"

    # remove users with undefined name (remove template)
	$xml.testsuite.testcase | Where-Object { $_.Name -eq "" } | ForEach-Object  { [void]$xml.testsuite.RemoveChild($_) }
	
    # save xml to file
    if (!(test-path $tgtPath -PathType Container)){
        mkdir $tgtPath
    }

    $tgtPath=[System.IO.Path]::Combine("${tgtPath}", "TEST-${testSuiteName}-${guid}.xml")

	$xml.Save("$tgtPath")
	Remove-Item $tempFile #clean up
    Write-Host "##vso[task.uploadfile]$tgtPath"

    return "$tgtPath"
    exit 0
}