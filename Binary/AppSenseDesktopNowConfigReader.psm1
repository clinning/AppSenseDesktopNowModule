$ConfigReader = New-Object -TypeName PSCustomObject
$ConfigReader.PSObject.TypeNames.Insert(0, "AppSenseDesktopNow.ConfigReaderObject")

Add-Member -InputObject $ConfigReader -MemberType NoteProperty -Name "Path" -Value "" -Force
Add-Member -InputObject $ConfigReader -MemberType ScriptMethod -Name "GetComponent" -Value {
    param([string]$Name)

    function _GetComponent {
        Param(
            [Parameter(Mandatory=$true, Position=1, HelpMessage='The component name to retrieve details for')]
            [string]$ComponentName
        )

        $json = Get-Content -Raw -Path $this.Path | ConvertFrom-Json
        return $json.components.$ComponentName
    }
    return _GetComponent $Name
}
Add-Member -InputObject $ConfigReader -MemberType ScriptMethod -Name "GetPrerequisite" -Value {
    param([string]$Name)

    function _GetPrerequisite {
        Param(
            [Parameter(Mandatory=$true, Position=1, HelpMessage='The pre-requisite to retrieve details for')]
            [string]$PrerequisiteName
        )

        $json = Get-Content -Raw -Path $this.Path | ConvertFrom-Json
        return $json.prerequisites.$PrerequisiteName
    }
    return _GetPrerequisite $Name
}
Add-Member -InputObject $ConfigReader -MemberType ScriptMethod -Name "GetSection" -Value {
    param([string]$Name)

    function _GetSection {
        Param(
            [Parameter(Mandatory=$true, Position=1, HelpMessage='The section to retrieve details for')]
            [string]$SectionName
        )

        $json = Get-Content -Raw -Path $this.Path | ConvertFrom-Json
        return $json.$SectionName
    }
    return _GetSection $Name
}
Export-ModuleMember -Variable ConfigReader