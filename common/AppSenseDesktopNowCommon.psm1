<##################################################################################################################
    Aim:        Sets up the defaults to be used for all modules in this suite of modules
##################################################################################################################>
function setDefaults() {
    return @{
        "Installer" = @{
            "DefaultConfig" = "$((Get-Item $PSScriptRoot).Parent.FullName)\Binary\resources\desktopnow.json"
            "BinPath" = "Bin"
            "PrereqPath" = "Software\Prerequisites"
            "ComponentPath" = "Software\Products"
        }
        "SCU" = @{
            "ModuleName" = "AppSenseInstances"
            "DBServerRoles" = @('dbcreator', 'securityadmin')
            "DBRoles" = @('db_owner')
        }
        "SCP" = @{
            "ModuleName" = "AppSense.ServerConfigurationPortal.PowerShell"
        }
        "Packages" = @{
            "ChunkSize" = 2097152
            "Description" = "API uploaded package"
        }
        "ManagementServer" = @{
            "WebServicesDLL" = "ManagementConsole.WebServices.dll"
            "LicensingDLL" = "Licensing.dll"
            "PackageManagerDLL" = "PackageManager.dll"
        }
        "PersonalizationServer" = @{
            "ProxyDLL" = "PSProxy4.dll"
        }
        "EMConfiguration" = @{
            "ConfigAPI" = "EMConfigAPI.dll"
        }
    }
}

<##################################################################################################################
    Aim:        Retrieves the Preference variables from the calling function.
    Notes:      Original source - https://gallery.technet.microsoft.com/scriptcenter/Inherit-Preference-82343b9d
##################################################################################################################>
function Get-CallerPreference {
    [CmdletBinding(DefaultParameterSetName = 'AllVariables')]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateScript({ $_.GetType().FullName -eq 'System.Management.Automation.PSScriptCmdlet' })]$Cmdlet,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.SessionState]$SessionState,

        [Parameter(ParameterSetName = 'Filtered', ValueFromPipeline = $true)]
        [string[]]$Name
    )

    Begin {
        $filterHash = @{}
    }
    Process {
        if ($null -ne $Name) {
            foreach ($string in $Name) { $filterHash[$string] = $true }
        }
    }
    End {
        # List of preference variables taken from the about_Preference_Variables help file in PowerShell version 4.0
        $vars = @{
            'ErrorView' = $null
            'FormatEnumerationLimit' = $null
            'LogCommandHealthEvent' = $null
            'LogCommandLifecycleEvent' = $null
            'LogEngineHealthEvent' = $null
            'LogEngineLifecycleEvent' = $null
            'LogProviderHealthEvent' = $null
            'LogProviderLifecycleEvent' = $null
            'MaximumAliasCount' = $null
            'MaximumDriveCount' = $null
            'MaximumErrorCount' = $null
            'MaximumFunctionCount' = $null
            'MaximumHistoryCount' = $null
            'MaximumVariableCount' = $null
            'OFS' = $null
            'OutputEncoding' = $null
            'ProgressPreference' = $null
            'PSDefaultParameterValues' = $null
            'PSEmailServer' = $null
            'PSModuleAutoLoadingPreference' = $null
            'PSSessionApplicationName' = $null
            'PSSessionConfigurationName' = $null
            'PSSessionOption' = $null
            'ErrorActionPreference' = 'ErrorAction'
            'DebugPreference' = 'Debug'
            'ConfirmPreference' = 'Confirm'
            'WhatIfPreference' = 'WhatIf'
            'VerbosePreference' = 'Verbose'
            'WarningPreference' = 'WarningAction'
        }
        foreach ($entry in $vars.GetEnumerator()) {
            if (([string]::IsNullOrEmpty($entry.Value) -or -not $Cmdlet.MyInvocation.BoundParameters.ContainsKey($entry.Value)) -and ($PSCmdlet.ParameterSetName -eq 'AllVariables' -or $filterHash.ContainsKey($entry.Name))) {
                $variable = $Cmdlet.SessionState.PSVariable.Get($entry.Key)
                if ($null -ne $variable) {
                    if ($SessionState -eq $ExecutionContext.SessionState) {
                        Set-Variable -Scope 1 -Name $variable.Name -Value $variable.Value -Force -Confirm:$false -WhatIf:$false
                    } else {
                        $SessionState.PSVariable.Set($variable.Name, $variable.Value)
                    }
                }
            }
        }
        if ($PSCmdlet.ParameterSetName -eq 'Filtered') {
            foreach ($varName in $filterHash.Keys) {
                if (-not $vars.ContainsKey($varName)) {
                    $variable = $Cmdlet.SessionState.PSVariable.Get($varName)
                    if ($null -ne $variable) {
                        if ($SessionState -eq $ExecutionContext.SessionState) {
                            Set-Variable -Scope 1 -Name $variable.Name -Value $variable.Value -Force -Confirm:$false -WhatIf:$false
                        } else {
                            $SessionState.PSVariable.Set($variable.Name, $variable.Value)
                        }
                    }
                }
            }
        }
    }
}

<##################################################################################################################
    Aim:        To retrieve the path that the AppSense components were installed in
    Notes:      Currently only checks for EM Config API and server instance related API files
    Returns:    [string] the path to the files required for loading 
##################################################################################################################>
function Get-DesktopNowDLLPath {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Instance,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Personalization Server", "Management Server", "EM Configuration")]
        [string]$Product
    )

    Begin {
        $ret = $false
    }
    Process {
        if ($Product -ne "EM Configuration") {
            $pathInstall = (Get-ChildItem -Path Registry::HKLM\SOFTWARE\AppSense\Instances | % { Get-ItemProperty -Path Registry::$($_.Name) | Where { $_.ProductName.Contains($Product) -and $_.Name -eq $Instance }}).InstallPath
            if ($Product.StartsWith("Personalization")) {
                $ret = Join-Path -Path (Split-Path -Path $pathInstall -Parent) -Child "API"
            } else {
                $ret = $false
            }
        } else {
            $strRegTest = "Registry::HKCR\AEMPFileAssociation"
            $ret = Test-Path $strRegTest
            if (-not $ret) { Throw 'EM console is not installed' }
            $path = (Get-ItemProperty -Path $strRegTest\shell\Open\command).'(default)'
            $ret = (Split-Path -Path $path).TrimStart('"')
        }
    }
    End {
        return $ret
    }
}

<##################################################################################################################
    Aim:        To test with a module is available for importing
    Returns:    System.Boolean
##################################################################################################################>
function Test-ModuleAvailability {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, Position=1, HelpMessage='The module to look for')]
        [string]$ModuleName = [string]::Empty,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Begin {
        if (Get-Command Get-CallerPreference -CommandType Function -ErrorAction SilentlyContinue) {
            Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        }
    }
    Process {
        Write-LogText "Checking if module $ModuleName is available" -TrackTime:$TrackTime.IsPresent
        $ret = (Get-Module -ListAvailable -Verbose:$false | Where Name -eq $ModuleName) -ne $null
        $msg = "$ModuleName is "
        if ($ret) { $msg += "available" } else { $msg += "not available" }
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    }
    End {
        return $ret
    }
}

<##################################################################################################################
    Aim:        To test whether a module is loaded
    Returns:    System.Boolean
##################################################################################################################>
function Test-ModuleLoaded {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$ModuleName,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Begin {
        if (Get-Command Get-CallerPreference -CommandType Function -ErrorAction SilentlyContinue) {
            Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        }
    }
    Process {
        Write-LogText "Checking if module $ModuleName is loaded" -TrackTime:$TrackTime.IsPresent
        $ret = Get-Module -Name $ModuleName -Verbose:$false
        $ret = if ($ret) { $true } else { $false }
    }
    End {
        $msg = "$ModuleName is "
        $msg += if ($ret) { "loaded" } else { "not loaded" }
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

<##################################################################################################################
    Aim:        To test whether a DLL is loaded
    Returns:    System.Boolean
##################################################################################################################>
function Test-DLLLoaded {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, Position=1, HelpMessage='The DLL to look for')]
        [string]$DLLName = [string]::Empty,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Begin {
        if (Get-Command Get-CallerPreference -CommandType Function -ErrorAction SilentlyContinue) {
            Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        }
    }
    Process {
        Write-LogText "Checking if $DLLName is loaded" -TrackTime:$TrackTime.IsPresent
        $dll = [AppDomain]::CurrentDomain.GetAssemblies() | Where FullName -like "$DLLName*"
        $ret = if ($dll) { $true } else { $false }
    }
    End {
        $msg = "$DLLName is "
        $msg += if (-not $ret) { "not " } else { "" }
        $msg += "already loaded"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

<##################################################################################################################
    Aim:        To write the given log text either to the screen, the log file or both
    Returns:    None
##################################################################################################################>
function Write-LogText {
    [CmdletBinding(DefaultParameterSetName='All')]
    Param(
        [Parameter(Mandatory=$true, Position=1)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime,

        [Parameter(Mandatory=$true, ParameterSetName='ScreenOnly')]
        [switch]$ScreenOnly,

        [Parameter(Mandatory=$true, ParameterSetName='LogFileOnly')]
        [switch]$LogFileOnly
    )

    Begin {
        if (Get-Command Get-CallerPreference -CommandType Function -ErrorAction SilentlyContinue) {
            Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        }
    }
    Process {
        $argsGLT = Get-MatchingCmdletParameters -CmdLet Get-LogText -CurrentParameters $PSBoundParameters
        $msg = Get-LogText @argsGLT
        if ($PSCmdlet.ParameterSetName -eq 'All' -or $PSCmdlet.ParameterSetName -eq 'ScreenOnly') {
            Write-Verbose $msg
        }
        if ($PSCmdlet.ParameterSetName -eq 'All' -or $PSCmdlet.ParameterSetName -eq 'ScreenOnly') {
            Out-LogFile -Message $msg | Out-Null
        }
    }
    End {}
}

<##################################################################################################################
    Aim:        To build the text for logging
    Returns:    System.String
##################################################################################################################>
function Get-LogText {
    Param(
        [Parameter(Mandatory=$true, Position=1)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    $ret = ""
    $ret += if ($TrackTime.IsPresent) { "$((Get-Date).ToLongTimeString()) " }
    $ret += $Message
    return $ret
}

<##################################################################################################################
    Aim:        To write the given text to the log file.
    Notes:      The path to the log file is built it does not exist.
    Returns:    System.Boolean
##################################################################################################################>
function Out-LogFile {
    Param(
        [Parameter(Mandatory=$true, Position=1, HelpMessage='The message that should be written to the file')]
        [string]$Message
    )

    try {
        if ($LogPath) {
            $dir = Split-Path $LogPath -Parent
            if (-not (Test-Path $dir)) { New-Item $dir -Type Directory -Force }
            Out-File -FilePath $LogPath -Append -InputObject $Message -Force
        }
        $ret = $true
    } catch {
        Write-Verbose $_
        $ret = $false
    }
    return $ret
}

<##################################################################################################################
    Aim:        To execute a given process with the arguments specified
    Returns:    System.Boolean | System.Int32 | System.String
    Notes:      Normal - will return System.Boolean
                StdOut - will return System.String
                ExitCode - will return System.Int32
##################################################################################################################>
function Start-ExternalProcess {
    [CmdletBinding(DefaultParameterSetName="Normal")]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Command,

        [Parameter(Mandatory=$false)]
        [string[]]$ArgumentList = @(),

        [Parameter(Mandatory=$false)]
        [string]$WorkingDirectory = [string]::Empty,

        [Parameter(Mandatory=$false, ParameterSetName='StdOut')]
        [switch]$ReturnStdOut,

        [Parameter(Mandatory=$false, ParameterSetName='ExitCode')]
        [switch]$UseShell,

        [Parameter(Mandatory=$false, ParameterSetName='ExitCode')]
        [switch]$ReturnExitCode,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Begin {
        $ret = $false
        if (Get-Command Get-CallerPreference -CommandType Function -ErrorAction SilentlyContinue) {
            Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        }
    }
    Process {
        $msg = "Executing $Command $ArgumentList"
        if (-not $Command.Contains($WorkingDirectory)) { $msg += " with working directory $WorkingDirectory" }
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        try {
            $p = New-Object System.Diagnostics.Process
            $p.StartInfo.FileName = $Command
            $p.StartInfo.Arguments = $ArgumentList -join " "
            $p.StartInfo.UseShellExecute = if ($UseShell.IsPresent) { $true } else { $false }
            $p.StartInfo.WorkingDirectory = $WorkingDirectory
            $p.StartInfo.CreateNoWindow = $true
            $p.StartInfo.LoadUserProfile = $true
            $p.StartInfo.RedirectStandardOutput = if ($ReturnStdOut.IsPresent) { $true } else { $false }
            $p.StartInfo.RedirectStandardError = if ($ReturnExitCode.IsPresent -and -not $UseShell.IsPresent) { $true } else { $false }
            $p.Start() | Out-Null
        } catch {
            $ret = $_
        } finally {
            if (-not $ret) {
                $p.WaitForExit()
                if ($ReturnExitCode.IsPresent) { # we need to return the exit code
                    $ret = $p.ExitCode
                } elseif ($ReturnStdOut.IsPresent) { # we need to return the StdOut
                    $ret = $p.StandardOutput.ReadToEnd()
                } else {
                    if ($p.ExitCode -eq 0) { # just need to return a boolean
                        $ret = $true
                    } else { # the below object is for display purposes
                        $ret = New-Object PSCustomObject -Property @{'Message'=$p.StandardError.ReadToEnd().Trim(); 'Code'=$p.ExitCode}
                    }
                }
            } else {
                $ret = $ret.Exception
            }
        }
    }
    End {
        $msg = "$Command $ArgumentList exited with "
        $msg += if ($ret.GetType().Name -eq "Int32") { "code $ret" } else { "" }
        $msg += if ($ret.Message) { "message: $($ret.Message) " } else { "" }
        $msg += if ($ret.Code) { "(code: $($ret.Code))" } else { "" }
        if ($ret.Message -or $ret.Code) { $ret = $false }
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

<##################################################################################################################
    Aim:        To test whether the current user is an administrator or not
    Returns:    System.Boolean
##################################################################################################################>
function Test-IsAdmin {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Begin {
        $ret = $false
        if (Get-Command Get-CallerPreference -CommandType Function -ErrorAction SilentlyContinue) {
            Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        }
    }
    Process {
        try {
            Write-LogText "Checking if current user is an Administrator" -TrackTime:$TrackTime.IsPresent
            [Security.Principal.WindowsPrincipal]$current = [Security.Principal.WindowsIdentity]::GetCurrent()
            $ret = $current.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        $msg = "Current user is "
        $msg += if (-not $ret) { "not " } else { "" }
        $msg += "an Administrator"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

<##################################################################################################################
    Aim:        To retrieve the name of the module in the given path.
    Returns:    System.String
##################################################################################################################>
function Get-ModuleName {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$ModulePath,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Begin {
        $ret = $false
        if (Get-Command Get-CallerPreference -CommandType Function -ErrorAction SilentlyContinue) {
            Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        }
    }
    Process {
        try {
            Write-LogText "Getting the current module name" -TrackTime:$TrackTime.IsPresent
            $psd1 = [System.IO.Path]::ChangeExtension($ModulePath, "psd1")
            $ret = (Test-ModuleManifest $psd1 -Verbose:$false).Name
            $ret = if ($ret) { $ret } else { $false }
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        return $ret
    }
}

<##################################################################################################################
    Aim:        To retrieve the DefaultCommandPrefix of the module in the given path.
    Returns:    System.String
##################################################################################################################>
function Get-ModuleDetails {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        [string]$Property,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Begin {
        $ret = $false
        if (Get-Command Get-CallerPreference -CommandType Function -ErrorAction SilentlyContinue) {
            Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        }
        $prevPP = $ProgressPreference
        $ProgressPreference = "SilentlyContinue"
    }
    Process {
        try {
            Write-LogText "Getting $Property from $Path" -TrackTime:$TrackTime.IsPresent
            $psd1 = [System.IO.Path]::ChangeExtension($Path, "psd1")
            $ret = (Test-ModuleManifest $psd1 -Verbose:$false).$Property
            $ret = if ($ret) { $ret } else { $false }
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        $ProgressPreference = $prevPP
        return $ret
    }
}

<##################################################################################################################
    Aim:        To take a username and password in plain text and return a PSCredential object
    Returns:    PSCredential | $false
##################################################################################################################>
function ConvertFrom-PlainCredentials {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$User = [string]::Empty,

        [Parameter(Mandatory=$true)]
        [string]$Password = [string]::Empty
    )

    try {
        $SecPass = ConvertTo-SecureString -AsPlainText $Password -Force
        $ret = New-Object System.Management.Automation.PSCredential($User, $SecPass)
    } catch {
        $ret = $false
    }
    return $ret
}

<##################################################################################################################
    Aim:        To take a username and password in plain text and return a PSCredential object
    Returns:    PSCredential | $false
##################################################################################################################>
function Get-UserCredentials {
    Param(
        [Parameter(Mandatory=$false)]
        [string]$Title,

        [Parameter(Mandatory=$false)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [string]$DefaultUser = [string]::Empty
    )

    try {
        $ret = $host.ui.PromptForCredential($Title, $Message, $DefaultUser, $null)
    } catch {
        $ret = $false
    }
    return $ret
}

<##################################################################################################################
    Aim:        To retrieve the password from a PSCredential object
    Returns:    System.String | $false
##################################################################################################################>
function Get-UserCredentialsPassword {
    Param(
        [Parameter(Mandatory=$true)]
        [PSCredential]$Credentials
    )

    try {
        $secPassword = $Credentials.Password
        $ptrPasword = [System.IntPtr]::Zero
        $ptrPasword = [Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($secPassword)
        $ret = [Runtime.InteropServices.Marshal]::PtrToStringUni($ptrPasword)
        [Runtime.InteropServices.Marshal]::ZeroFreeGlobalAllocUnicode($ptrPasword)
    } catch {
        $ret = $false
    }
    return $ret
}

<##################################################################################################################
    Aim:        To buld a URL from the given parameters
    Returns:    System.String
##################################################################################################################>
function New-URL {
    Param(
        [Parameter(Mandatory=$false)]
        [string]$Host,

        [Parameter(Mandatory=$false)]
        [int]$Port,

        [Parameter(Mandatory=$false)]
        [switch]$UseHTTPS,

        [Parameter(Mandatory=$false)]
        [switch]$NoProtocol
    )

    try {
        if (-not $NoProtocol) {
            $url = if ($UseHTTPS.IsPresent) { 'https' } else { 'http' }
            $url += "://"
        } else {
            $url = ""
        }
        $p = if ($port) { ":$port" } else { "" }
        $url += $Host + $p
        return $url
    } catch {
        return $false
    }
}

<##################################################################################################################
    Aim:        To set the log file that should be used
    Notes:      Sets the log file path as a global variable
    Returns:    System.Boolean
##################################################################################################################>
function Set-LogPath {
    # .ExternalHelp AppSenseDesktopNowCommon.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Begin {
        $ret = $false
        if (Get-Command Get-CallerPreference -CommandType Function -ErrorAction SilentlyContinue) {
            Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        }
    }
    Process {
        try {
            Write-LogText "Setting the log path to $Path" -TrackTime:$TrackTime.IsPresent
            Set-Variable -Name LogPath -Scope Global -Value $Path
            $ret = $true
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        $msg = "Log path was set "
        $msg += if ($ret) { "" } else { "not " }
        $msg += "successfully"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

<##################################################################################################################
    Aim:        To establish the parameters that can be passed to a cmdlet
    Notes:      Does not ensure that ParameterSets are adhered to
    Returns:    A hash table of the valid parameters that can be passed to a given cmdlet
##################################################################################################################>
function Get-MatchingCmdletParameters {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Cmdlet,

        [Parameter(Mandatory=$true)]
        $CurrentParameters
    )

    Begin {
        $ret = $false
        $prevPP = $ProgressPreference
        $ProgressPreference = "SilentlyContinue"
    }
    Process {
        try {
            $cmdS1 = $Cmdlet.Split('-')
            $cmd = (Get-Command -Name ($cmdS1 -join '-*') | Where ModuleName -Like "AppSense*" | Select -First 1).Name
            $paramsAvailable = (Get-Command $cmd).Parameters
            $paramsRet = @{}
            foreach($i in $CurrentParameters.Keys) {
                if ($paramsAvailable.Keys.Contains($i)) { $paramsRet.Add($i, $CurrentParameters[$i]) }
            }
            $ret = $paramsRet
        } catch {
            $ret = $false
        }
    }
    End {
        $ProgressPreference = $prevPP
        return $ret
    }
}

<##################################################################################################################
    Aim:        To return the given values from a the specified table in the specified installer file
    Notes:      Defaults to the Property table
    Returns:    System.Boolean
##################################################################################################################>
function Get-InstallerProperty {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$false)]
        [string]$Table = 'Property',

        [Parameter(Mandatory=$false)]
        [string[]]$Properties,

        [Parameter(Mandatory=$false)]
        [string]$KeyColumn = "Property",

        [Parameter(Mandatory=$false)]
        [string]$ValueColumn = "Value",

        [Parameter(Mandatory=$false)]
        [string]$ColumnToMatch = 'Property',

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Begin {
        $ret = $false
        if (Get-Command Get-CallerPreference -CommandType Function -ErrorAction SilentlyContinue) {
            Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        }
    }
    Process {
        try {
            if (-not (Test-Path $Path)) { Throw("$Path does not exist") }
            $qry = "SELECT * FROM $table"
            if ($Properties) { $qry += " WHERE " }
            $i = 1
            foreach ($p in $Properties) {
                if ($i -gt 1) { $qry += " OR " }
                $qry += "$ColumnToMatch = '$p'"
                $i++
            }
            Write-LogText "Reading properties from $Path" -TrackTime:$TrackTime.IsPresent
            $objInstaller = New-Object -ComObject 'WindowsInstaller.Installer'
            $openMode = 0
            if ([System.IO.Path]::GetExtension($Path).ToLower() -eq '.msp') { $openMode += 32 }
            $objDB = $objInstaller.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $objInstaller, @($Path, $openMode))
            $objView = $objDB.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $objDB, @($qry))
            $objViewColumns = $objView.GetType().InvokeMember('ColumnInfo', 'GetProperty', $null, $objView, 0)
            $colCount = $objViewColumns.GetType().InvokeMember('FieldCount', 'GetProperty', $null, $objViewColumns, $null)
            [void]$objView.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $objView, $null)
            $objRec = $objView.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $objView, $null)
            if ($objRec) { $ret = @{} }
            for ($i=1; $i -le $colCount; $i+=1) {
                $colName = $objViewColumns.GetType().InvokeMember('StringData', 'GetProperty', $null, $objViewColumns, $i)
                if ($colName -eq $KeyColumn) { $idxKey = $i }
                if ($colName -eq $ValueColumn) { $idxValue = $i }
            }
            while ($objRec) {
                $n = $objRec.GetType().InvokeMember('StringData', 'GetProperty', $null, $objRec, $idxKey)
                $v = $objRec.GetType().InvokeMember('StringData', 'GetProperty', $null, $objRec, $idxValue)
                $ret.Add($n, $v)
                $objRec = $objView.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $objView, $null)
            }
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        } finally {
            if ($objRec) { [void][System.Runtime.Interopservices.Marshal]::ReleaseComObject($objRec) }
            if ($objViewColumns) { [void][System.Runtime.Interopservices.Marshal]::ReleaseComObject($objViewColumns) }
            if ($objView) { [void][System.Runtime.Interopservices.Marshal]::ReleaseComObject($objView) }
            if ($objDB) { [void][System.Runtime.Interopservices.Marshal]::ReleaseComObject($objDB) }
            if ($objInstaller) { [void][System.Runtime.Interopservices.Marshal]::ReleaseComObject($objInstaller) }
        }
    }
    End {
        $msg = if ($ret) { "Successfully" } else { "Failed to" }
        $msg += " retrieve"
        $msg += if ($ret) { "d " } else { " " }
        $msg += "properties from $Path"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

function Get-InstallerMetadata {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$false)]
        [string]$Table = "ProductMetadata",

        [Parameter(Mandatory=$true)]
        [string]$MetadataName,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        if (-not (Test-Path $Path)) { Throw("$Path does not exist") }
        $openMode = 0
        if ([System.IO.Path]::GetExtension($Path).ToLower() -eq '.msp') { $openMode = 32 }
        $objInstaller = New-Object -ComObject 'WindowsInstaller.Installer'
        $objDB = $objInstaller.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $objInstaller, @($Path, $openMode))
        $qry = "SELECT Data FROM $Table WHERE Name = '$MetadataName'"
        $objView = $objDB.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $objDB, @($qry))
        [void]$objView.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $objView, $null)
        $objRec = $objView.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $objView, $null)
        $size = $objRec.GetType().InvokeMember('DataSize', 'GetProperty', $null, $objRec, 1)
        $val = $objRec.GetType().InvokeMember('ReadStream', 'InvokeMethod', $null, $objRec, @(1, $size, 2))
        [void]$objView.GetType().InvokeMember('Close', 'InvokeMethod', $null, $objView, $null)
        if ($val) {
            $ret = if ($val.Substring(0, 3) -match '\u00EF\u00BB\u00BF') { $val.Substring(3) } else { $val }
        }
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    } finally {
        if ($objRec) { [void][System.Runtime.Interopservices.Marshal]::ReleaseComObject($objRec) }
        if ($objView) { [void][System.Runtime.Interopservices.Marshal]::ReleaseComObject($objView) }
        if ($objDB) { [void][System.Runtime.Interopservices.Marshal]::ReleaseComObject($objDB) }
        if ($objInstaller) { [void][System.Runtime.Interopservices.Marshal]::ReleaseComObject($objInstaller) }
    }
    return $ret
}

function Get-InstallerSummaryInfoStream {
    [CmdletBinding(DefaultParameterSetName='All')]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true, ParameterSetName='ByProperty')]
        [int[]]$Property,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Begin {
        $ret = $false
        if (Get-Command Get-CallerPreference -CommandType Function -ErrorAction SilentlyContinue) {
            Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        }
    }
    Process {
        try {
            if (-not (Test-Path $Path)) { Throw("$Path does not exist") }
            Write-LogText "Reading properties from $Path" -TrackTime:$TrackTime.IsPresent
            $objInstaller = New-Object -ComObject 'WindowsInstaller.Installer'
            $objSI = $objInstaller.GetType().InvokeMember('SummaryInformation', 'GetProperty', $null, $objInstaller, @($Path, 0))
            if ($PSCmdlet.ParameterSetName -eq 'ByProperty') {
                $ret = @()
                foreach($p in $Property) { $ret += $objSI.GetType().InvokeMember('Property', 'GetProperty', $null, $objSI, $p) }
            } else {
                $ret = @()
                for ($p=0; $p -le 19; $p++) { $ret += $objSI.GetType().InvokeMember('Property', 'GetProperty', $null, $objSI, $p) }
            }
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        } finally {
            if ($objSI) { [void][System.Runtime.Interopservices.Marshal]::ReleaseComObject($objSI) }
            if ($objInstaller) { [void][System.Runtime.Interopservices.Marshal]::ReleaseComObject($objInstaller) }
        }
    }
    End {
        $msg = if ($ret) { "Successfully" } else { "Failed to" }
        $msg += " retrieve"
        $msg += if ($ret) { "d " } else { " " }
        $msg += "summary information from $Path"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

function Get-InstallerPatchXMLData {
    [CmdletBinding(DefaultParameterSetName='All')]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Begin {
        $ret = $false
        if (Get-Command Get-CallerPreference -CommandType Function -ErrorAction SilentlyContinue) {
            Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        }
    }
    Process {
        try {
            if (-not (Test-Path $Path)) { Throw("$Path does not exist") }
            Write-LogText "Reading XML from $Path" -TrackTime:$TrackTime.IsPresent
            $objInstaller = New-Object -ComObject 'WindowsInstaller.Installer'
            $ret = $objInstaller.GetType().InvokeMember('ExtractPatchXMLData', 'InvokeMethod', $null, $objInstaller, @($Path, 0))
            if ($ret) { $ret = [xml]$ret }
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        } finally {
            if ($objSI) { [void][System.Runtime.Interopservices.Marshal]::ReleaseComObject($objSI) }
            if ($objInstaller) { [void][System.Runtime.Interopservices.Marshal]::ReleaseComObject($objInstaller) }
        }
    }
    End {
        $msg = if ($ret) { "Successfully" } else { "Failed to" }
        $msg += " retrieve"
        $msg += if ($ret) { "d " } else { " " }
        $msg += "XML information from $Path"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

<##################################################################################################################
    Aim:        To set a property in the Property table of an MSI or MSP
    Notes:      Only works with the Property or MsiPatchMetadata table.
                Should and will not work with any other table in the installer database
    Returns:    System.Boolean
##################################################################################################################>
function Set-InstallerProperty {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$false)]
        [System.Collections.Hashtable]$Values,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Begin {
        $ret = $false
        if (Get-Command Get-CallerPreference -CommandType Function -ErrorAction SilentlyContinue) {
            Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        }
    }
    Process {
        try {
            if (-not (Test-Path $Path)) { Throw("$Path does not exist") }
            if (-not $Values) { Throw("Invalid values supplied") }
            Write-LogText "Storing values in $Path" -TrackTime:$TrackTime.IsPresent
            $objInstaller = New-Object -ComObject 'WindowsInstaller.Installer'
            $openMode = 1
            $table = 'Property'
            if ([System.IO.Path]::GetExtension($Path).ToLower() -eq '.msp') {
                $openMode += 32
                $table = 'MsiPatchMetadata'
            }
            $objDB = $objInstaller.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $objInstaller, @($Path, $openMode))
            foreach ($i in $Values.GetEnumerator()) {
                $qry = "INSERT INTO $table (Property, Value) VALUES ($($i.Name), $($i.Value))"
                $objView = $objDB.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $objDB, @($qry))
                [void]$objView.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $objView, $null)
            }
            $objDB.GetType().InvokeMember('Commit', 'InvokeMethod', $null, $objDB, $null)
            $objView.GetType().InvokeMember('Close', 'InvokeMethod', $null, $objView, $null)
            $ret = $true
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        } finally {
            if ($objRec) { [void][System.Runtime.Interopservices.Marshal]::ReleaseComObject($objRec) }
            if ($objViewColumns) { [void][System.Runtime.Interopservices.Marshal]::ReleaseComObject($objViewColumns) }
            if ($objView) { [void][System.Runtime.Interopservices.Marshal]::ReleaseComObject($objView) }
            if ($objDB) { [void][System.Runtime.Interopservices.Marshal]::ReleaseComObject($objDB) }
            if ($objInstaller) { [void][System.Runtime.Interopservices.Marshal]::ReleaseComObject($objInstaller) }
        }
    }
    End {
        $msg = if ($ret) { "Successfully" } else { "Failed to" }
        $msg += " store"
        $msg += if ($ret) { "d " } else { " " }
        $msg += "properties in $Path"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

<##################################################################################################################
    Aim:        To test if an API method is actually availble on the given connection
    Returns:    [boolean] false if not found or an error occurs
                [string] the definition property of the function  
##################################################################################################################>
function Test-APIFunctionAvailable {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        $ConnectionObject,

        [Parameter(Mandatory=$true)]
        [string]$Name
    )

    Begin {
        $ret = $false
        if (Get-Command Get-CallerPreference -CommandType Function -ErrorAction SilentlyContinue) {
            Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        }
    }
    Process {
        try {
            $ret = $ConnectionObject | Get-Member -Name $Name | Select -ExpandProperty Definition
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        }
    }
    End {
        return $ret
    }
}

Set-Variable -Name AppSenseDefaults -Option Constant -Value (setDefaults)

Export-ModuleMember -Function *-*
Export-ModuleMember -Variable AppSenseDefaults