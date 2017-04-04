function Connect-Instance {
    # .ExternalHelp AppSenseDesktopNowConfiguration.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [AppSenseDesktopNowSCU.Products]$ProductName,

        [Parameter(Mandatory=$false)]
        [string]$InstanceName = [string]::Empty,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        $msg = "Connecting to "
        $msg += if ($InstanceName -ne [string]::Empty) { "$InstanceName for " } else { "" }
        $msg += $ProductName
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        $res = Import-AppSenseInstancesModule -TrackTime:$TrackTime.IsPresent
        if ($res) {
            #-- Find the instance that we're after --#
            $i = Get-InstanceProperties -ProductName $ProductName -InstanceName $InstanceName -TrackTime:$TrackTime.IsPresent
            if ($i) {
                #-- Found the instance so connect to it now --#
                Import-ApsInstanceModule -InstanceId $i.InstanceId -Verbose:$false | Out-Null
                $ret = $true
            }
        }
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    $msg = if ($ret) { "Successfully connected to " } else { "Unable to connect to " }
    $msg += if ($InstanceName -ne [string]::Empty) { "$InstanceName for " } else { "" }
    $msg += $ProductName
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

function Get-InstanceInstallPath {
    # .ExternalHelp AppSenseDesktopNowConfiguration.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [AppSenseDesktopNowSCU.Products]$ProductName,

        [Parameter(Mandatory=$false)]
        [string]$InstanceName = [string]::Empty,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        $msg = "Retrieving install path from "
        $msg += if ($InstanceName -ne [string]::Empty) { "$InstanceName for " } else { "" }
        $msg += $ProductName
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        $ret = Get-InstanceProperties @PSBoundParameters
        if ($ret) {
            $ret = $ret.InstallPath
            if ($ret[-1] -eq '\') { $ret = $ret -replace ".$" }
        }
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    $msg = if ($ret) { "Successfully retrieved install path from " } else { "Failed to retrieve install path from " }
    $msg += if ($InstanceName -ne [string]::Empty) { "$InstanceName for " } else { "" }
    $msg += $ProductName
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

function Initialize-Instance {
    # .ExternalHelp AppSenseDesktopNowConfiguration.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [AppSenseDesktopNowSCU.Products]$ProductName,

        [Parameter(Mandatory=$false)]
        [AppSenseDesktopNowSCU.WebsiteAuthenticationType]$WebsiteAuthentication = [AppSenseDesktopNowSCU.WebsiteAuthenticationType]::Windows,

        [Parameter(Mandatory=$false)]
        [string]$WebsiteName= [string]::Empty,

        [Parameter(Mandatory=$false)]
        [string]$InstanceName = [string]::Empty,

        [Parameter(Mandatory=$false)]
        [ValidateRange(1,65535)]
        [uint16]$WebsitePort,

        [Parameter(Mandatory=$false)]
        [string]$DatabaseConnection,

        [Parameter(Mandatory=$true)]
        [string]$DatabaseServer,

        [Parameter(Mandatory=$true)]
        [string]$DatabaseName,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServicePlain')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServiceCreds')]
        [string]$ConfigurationUser = [string]::Empty,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServicePlain')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServiceCreds')]
        [string]$ConfigurationPassword = [string]::Empty,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigCredsServicePlain')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigCredsServiceCreds')]
        [System.Management.Automation.PSCredential]$ConfigurationCredentials = [PSCredential]::Empty,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServicePlain')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigCredsServicePlain')]
        [string]$ServiceUser = [string]::Empty,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServicePlain')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigCredsServicePlain')]
        [string]$ServicePassword = [string]::Empty,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServiceCreds')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigCredsServiceCreds')]
        [System.Management.Automation.PSCredential]$ServiceCredentials = [PSCredential]::Empty,

        [Parameter(Mandatory=$false)]
        [switch]$CreateWebsite,

        [Parameter(Mandatory=$false)]
        [switch]$ConfirmConfigurer,

        [Parameter(Mandatory=$false)]
        [switch]$CreateConfigurer,

        [Parameter(Mandatory=$false)]
        [switch]$ConfigurerSqlAuthentication,

        [Parameter(Mandatory=$false)]
        [switch]$ServiceSqlAuthentication,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        Write-LogText "Starting configuration of $ProductName" -TrackTime:$TrackTime.IsPresent
        $paramsAll = @{} + $PSBoundParameters
        if (Connect-Instance -InstanceName $InstanceName -ProductName $ProductName -TrackTime:$TrackTime.IsPresent) {
            #-- Check the pre-reqs are all available --#
            $pMissing = Get-ApsPrerequisite
            if ($pMissing.Count) {
                $pMissing | Install-ApsPrerequisite
                $pMissing = Get-ApsPrerequisite
            }
            if ($pMissing.Count) { Throw('Not all pre-requisites were fixed') }
            #-- Set up the credential objects --#
            if ($PSCmdlet.ParameterSetName.Contains('ConfigPlain')) {
                $ConfigurationCredentials = ConvertFrom-PlainCredentials -User $ConfigurationUser -Password $ConfigurationPassword
            }
            if ($PSCmdlet.ParameterSetName.Contains('ServicePlain')) {
                $ServiceCredentials = ConvertFrom-PlainCredentials -User $ServiceUser -Password $ServicePassword
            }
            $paramsAll.Add('ConfigurerCredential', $ConfigurationCredentials)
            $paramsAll.Add('ServiceCredential', $ServiceCredentials)
            #-- Initialize the DB --#
            $blnContinue = $true
            $ApsDatabaseArgs = Get-MatchingCmdletParameters -Cmdlet "Test-InstanceDatabaseUpgrade" -CurrentParameters $paramsAll
            Test-InstanceDatabaseUpgrade @ApsDatabaseArgs | Out-Null #check if an upgrade is needed but only display messages don't react
            $ApsDatabaseArgs = Get-MatchingCmdletParameters -Cmdlet "Initialize-InstanceDatabase" -CurrentParameters $paramsAll
            $blnContinue = Initialize-InstanceDatabase @ApsDatabaseArgs
            if ($blnContinue) {
                #-- Initialize the WebSite --#
                $ApsServerArgs = Get-MatchingCmdletParameters -Cmdlet "Initialize-InstanceWebsite" -CurrentParameters $paramsAll
                if (Initialize-InstanceWebsite @ApsServerArgs) {
                    #-- Check for variances and repair if necessary --#
                    $VarianceArgs = Get-MatchingCmdletParameters -Cmdlet "Test-InstanceVariance" -CurrentParameters $paramsAll
                    if (Test-InstanceVariance @VarianceArgs) { Repair-InstanceVariance -TrackTime | Out-Null }
                    #-- Get the instance status --#
                    Write-LogText "Checking instance status" -TrackTime:$TrackTime.IsPresent -Verbose
                    $i = Get-ApsCurrentInstance
                    Write-LogText "Instance status: $($i.Status)" -TrackTime:$TrackTime.IsPresent -Verbose
                    $ret = if ($i.Status -eq 'Started') { $i.InstanceId.ToString() } else { $false }
                }
            } else {
                $ret = $false
            }
        }
    } catch {
        Write-LogText $_ -TrackTime:$rackTime.IsPresentVarianceArgs
        $ret = $false
    }
    $msg = "$ProductName was "
    $msg += if (-not $ret) { "not " }
    $msg += "completed successfully"
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

function Initialize-InstanceWebsite {
    # .ExternalHelp AppSenseDesktopNowConfiguration.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [AppSenseDesktopNowSCU.Products]$ProductName,

        [Parameter(Mandatory=$false)]
        [AppSenseDesktopNowSCU.WebsiteAuthenticationType]$WebsiteAuthentication = [AppSenseDesktopNowSCU.WebsiteAuthenticationType]::Windows,

        [Parameter(Mandatory=$false)]
        [string]$WebsiteName = [string]::Empty,

        [Parameter(Mandatory=$false)]
        [string]$InstanceName = [string]::Empty,

        [Parameter(Mandatory=$false)]
        [ValidateRange(1,65535)]
        [uint16]$WebsitePort,

        [Parameter(Mandatory=$true)]
        [string]$DatabaseServer,

        [Parameter(Mandatory=$true)]
        [string]$DatabaseName,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServicePlain')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServiceCreds')]
        [string]$ConfigurationUser = [string]::Empty,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServicePlain')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServiceCreds')]
        [string]$ConfigurationPassword = [string]::Empty,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigCredsServicePlain')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigCredsServiceCreds')]
        [System.Management.Automation.PSCredential]$ConfigurationCredentials = [PSCredential]::Empty,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServicePlain')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigCredsServicePlain')]
        [string]$ServiceUser = [string]::Empty,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServicePlain')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigCredsServicePlain')]
        [string]$ServicePassword = [string]::Empty,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServiceCreds')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigCredsServiceCreds')]
        [System.Management.Automation.PSCredential]$ServiceCredentials = [PSCredential]::Empty,

        [Parameter(Mandatory=$false)]
        [switch]$CreateWebsite,

        [Parameter(Mandatory=$false)]
        [switch]$ConfigurerSqlAuthentication,

        [Parameter(Mandatory=$false)]
        [switch]$ServiceSqlAuthentication,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    $ret = $false
    try {
        Write-LogText "Starting configuration of the web site for $ProductName" -TrackTime:$TrackTime.IsPresent
        $propInstance = Get-InstanceProperties -ProductName $ProductName -InstanceName $InstanceName -TrackTime:$TrackTime.IsPresent
        if (-not $propInstance) { Throw('Instance not found') }
        $ApsServerArgList = @{} + $PSBoundParameters
        $ApsServerArgList.Remove("TrackTime")
        $ApsServerArgList.Remove("CreateWebsite")
        $ApsServerArgList.Remove("InstanceName")
        $ApsServerArgList.Remove("ProductName")
        $ApsServerArgList.Remove("WebsitePort")
        #-- Set up the credential objects --#
        if ($PSCmdlet.ParameterSetName.Contains('ConfigPlain')) {
            $ConfigurationCredentials = ConvertFrom-PlainCredentials -User $ConfigurationUser -Password $ConfigurationPassword
            $ApsServerArgList.Remove("ConfigurationUser")
            $ApsServerArgList.Remove("ConfigurationPassword")
        } elseif ($PSCmdlet.ParameterSetName.Contains('ConfigCreds')) {
            $ApsServerArgList.Remove("ConfigurationCredentials")
        }
        $ApsServerArgList.Add('ConfigurerCredential', $ConfigurationCredentials)
        if ($PSCmdlet.ParameterSetName.Contains('ServicePlain')) {
            $ServiceCredentials = ConvertFrom-PlainCredentials -User $ServiceUser -Password $ServicePassword
            $ApsServerArgList.Remove("ServiceUser")
            $ApsServerArgList.Remove("ServicePassword")
        } elseif ($PSCmdlet.ParameterSetName.Contains('ServiceCreds')) {
            $ApsServerArgList.Remove("ServiceCredentials")
        }
        $ApsServerArgList.Add('ServiceCredential', $ServiceCredentials)
        #-- Build the arguments needed for the Initialize-ApsServer Cmdlet --#
        if ($WebsiteName -eq [string]::Empty) {
            if ($propInstance.Version.Major -lt 10) {
                $ApsServerArgList.WebsiteName = if ($InstanceName) { $InstanceName } else { "Default Web Site" }
            } else {
                $ApsServerArgList.WebsiteName = $InstanceName
                $ApsServerArgList.WebsiteName += if ($propInstance.ProductName.Contains("Management")) { "Management" } else { "Personalization" }
            }
        }
        $InstallMode = Get-SCUProductInstallMode $ProductName
        if ($InstallMode) { $ApsServerArgList.Add('InstallMode', $InstallMode) }
        #-- Check if the WebSite already exists --#
        if (-not (Test-IISWebsite -Name $ApsServerArgList.WebsiteName -TrackTime:$TrackTime.IsPresent)) {
            if ($propInstance.Version.Major -ge 10) {
                if (-not $WebsitePort) {
                    Write-LogText "Determing website port to use" -TrackTime:$TrackTime.IsPresent
                    $i = Get-ApsServerDetail
                    if ($i) {
                        $WebsitePort = $i.LocalPort
                        $CreateWebsite = $true
                    }
                }
            }
            if (-not $WebsitePort) { Throw("No port number specified for website `"$($ApsServerArgList.WebsiteName)`"") }
            #-- Create the WebSite if we need to --#
            if ($CreateWebsite.IsPresent) {
                $pathPhysical = Split-Path -Path (Get-InstanceInstallPath -ProductName $ProductName -InstanceName $InstanceName -TrackTime:$TrackTime.IsPresent -Verbose) -Parent
                if (-not (New-IISWebsite -Name $ApsServerArgList.WebsiteName -Port $WebsitePort -PhysicalPath $pathPhysical -TrackTime:$TrackTime.IsPresent)) { Throw("Error creating $WebsiteName") }
            } else {
                Throw("Website `"$($ApsServerArgList.WebsiteName)`" does not exist and CreateWebsite parameter not supplied")
            }
        } else {
            if ($WebsitePort) { Write-Verbose (Get-LogText "Ignoring the WebsitePort parameter" -TrackTime:$TrackTime.IsPresent) }
        }
        #-- Initialize the IIS Site --#
        $ApsServerArgList.Add('Force', $true)
        Initialize-ApsServer @ApsServerArgList #-ErrorAction Stop
        $ret = $true
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    $msg = "The web site for $ProductName was "
    $msg += if (-not $ret) { "not " }
    $msg += "completed successfully"
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

function Initialize-InstanceDatabase {
    # .ExternalHelp AppSenseDesktopNowConfiguration.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$DatabaseServer,

        [Parameter(Mandatory=$true)]
        [string]$DatabaseName,

        [Parameter(Mandatory=$false)]
        [string]$DatabaseConnection,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServicePlain')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServiceCreds')]
        [string]$ConfigurationUser = [string]::Empty,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServicePlain')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServiceCreds')]
        [string]$ConfigurationPassword = [string]::Empty,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigCredsServicePlain')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigCredsServiceCreds')]
        [System.Management.Automation.PSCredential]$ConfigurerCredential = [PSCredential]::Empty,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServicePlain')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigCredsServicePlain')]
        [string]$ServiceUser = [string]::Empty,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServicePlain')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigCredsServicePlain')]
        [string]$ServicePassword = [string]::Empty,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServiceCreds')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigCredsServiceCreds')]
        [System.Management.Automation.PSCredential]$ServiceCredential = [PSCredential]::Empty,

        [Parameter(Mandatory=$false)]
        [switch]$ConfigurerSqlAuthentication,

        [Parameter(Mandatory=$false)]
        [switch]$ServiceSqlAuthentication,

        [Parameter(Mandatory=$false)]
        [switch]$ConfirmConfigurer,

        [Parameter(Mandatory=$false)]
        [switch]$CreateConfigurer,

        [Parameter(Mandatory=$false)]
        [switch]$DoNotForce,

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
            $continue = $true
            $cmdlet = "Initialize-ApsDatabase"
            Write-LogText "Initialising $DatabaseName on $DatabaseServer" -TrackTime:$TrackTime.IsPresent
            if (Test-CmdletAvailablilty -CmdletName $cmdlet -TrackTime:$TrackTime.IsPresent) {
                $ArgList = @{} + $PSBoundParameters
                $ArgList.Remove("TrackTime")
                $ArgList.Add('Force', (-not $DoNotForce.IsPresent))
                $ArgList.Remove("DoNotForce")
                $ArgList.Remove('CreateConfigurer')
                $ArgList.Remove('ConfirmConfigurer')
                #-- Set up the credential objects --#
                if ($PSCmdlet.ParameterSetName.Contains('ConfigPlain')) {
                    $ConfigurationCredentials = ConvertFrom-PlainCredentials -User $ConfigurationUser -Password $ConfigurationPassword
                    $ArgList.Add("ConfigurerCredential", $ConfigurationCredentials)
                    $ArgList.Remove("ConfigurationUser")
                    $ArgList.Remove("ConfigurationPassword")
                }
                if ($PSCmdlet.ParameterSetName.Contains('ServicePlain')) {
                    $ServiceCredentials = ConvertFrom-PlainCredentials -User $ServiceUser -Password $ServicePassword
                    $ArgList.Add("ServiceCredential", $ServiceCredentials)
                    $ArgList.Remove("ServiceUser")
                    $ArgList.Remove("ServicePassword")
                }
                if ($ConfirmConfigurer.IsPresent) {
                    $sqlInfo = $DatabaseServer.Split('\')
                    $userExists = Test-SQLUserIsValidConfigurationUser -Username $ArgList.ConfigurerCredential.UserName -SQLServer $sqlInfo[0] -SQLInstance $sqlInfo[1] -TrackTime:$TrackTime.IsPresent
                    if (-not $userExists) {
                        $continue = $false
                        $ret = $false
                    }
                }
                if ($CreateConfigurer.IsPresent) {
                    $sqlInfo = $DatabaseServer.Split('\')
                    $sqlParams = @{'Username'=$ArgList.ConfigurerCredential.UserName; 'SQLServer'=$sqlInfo[0]; 'SQLInstance'=$sqlInfo[1]; 'TrackTime'=$TrackTime.IsPresent; 'Verbose'=$true}
                    $userExists = Test-SQLUserIsValidConfigurationUser @sqlParams
                    if (-not $userExists) {
                        if ($ConfigurerSqlAuthentication.IsPresent) { $sqlParams.Add('Password', (Get-UserCredentialsPassword -Credentials $ArgList.ConfigurerCredential)) }
                        Set-SQLUserToValidConfigurationUser @sqlParams | Out-Null
                    }
                }
                if ($continue) {
                    & $cmdlet @ArgList
                    $ret = $true
                }
            }
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        $msg = "The database "
        $msg += if (-not $ret) { "did not initialise " } else { "initialised " }
        $msg += "successfully"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

function Update-InstanceDatabase {
    # .ExternalHelp AppSenseDesktopNowConfiguration.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$DatabaseServer,

        [Parameter(Mandatory=$true)]
        [string]$DatabaseName,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServicePlain')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServiceCreds')]
        [string]$ConfigurationUser = [string]::Empty,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServicePlain')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServiceCreds')]
        [string]$ConfigurationPassword = [string]::Empty,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigCredsServicePlain')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigCredsServiceCreds')]
        [System.Management.Automation.PSCredential]$ConfigurerCredential = [PSCredential]::Empty,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServicePlain')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigCredsServicePlain')]
        [string]$ServiceUser = [string]::Empty,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServicePlain')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigCredsServicePlain')]
        [string]$ServicePassword = [string]::Empty,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServiceCreds')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigCredsServiceCreds')]
        [System.Management.Automation.PSCredential]$ServiceCredential = [PSCredential]::Empty,

        [Parameter(Mandatory=$false)]
        [switch]$ConfigurerSqlAuthentication,

        [Parameter(Mandatory=$false)]
        [switch]$ServiceSqlAuthentication,

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
            $p = @{} + $PSBoundParameters
            $p.Add('DoNotForce', $false)
            $ret = Initialize-InstanceDatabase @p
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        return $ret
    }
}

function Test-InstanceDatabaseUpgrade {
    # .ExternalHelp AppSenseDesktopNowConfiguration.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$DatabaseServer,

        [Parameter(Mandatory=$false)]
        [string]$DatabaseName,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServicePlain')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServiceCreds')]
        [string]$ConfigurationUser = [string]::Empty,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServicePlain')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServiceCreds')]
        [string]$ConfigurationPassword = [string]::Empty,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigCredsServicePlain')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigCredsServiceCreds')]
        [System.Management.Automation.PSCredential]$ConfigurerCredential = [PSCredential]::Empty,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServicePlain')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigCredsServicePlain')]
        [string]$ServiceUser = [string]::Empty,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServicePlain')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigCredsServicePlain')]
        [string]$ServicePassword = [string]::Empty,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlainServiceCreds')]
        [Parameter(Mandatory=$true, ParameterSetName='ConfigCredsServiceCreds')]
        [System.Management.Automation.PSCredential]$ServiceCredential = [PSCredential]::Empty,

        [Parameter(Mandatory=$false)]
        [switch]$ConfigurerSqlAuthentication,

        [Parameter(Mandatory=$false)]
        [switch]$ServiceSqlAuthentication,

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
            Write-LogText "Testing if the database needs an upgrade" -TrackTime:$TrackTime.IsPresent
            $cmdlet = "Initialize-ApsDatabase"
            $match = 'no upgrade is required|has later version than the current'
            if (Test-CmdletAvailablilty -CmdletName $cmdlet -TrackTime:$TrackTime.IsPresent) {
                $ArgList = @{} + $PSBoundParameters
                $ArgList.Remove("TrackTime")
                $paramInitDB = (Get-Command $cmdlet).Parameters
                if ($paramInitDB.Keys.Contains('ReportOnly')) {
                    $ArgList.Add("ReportOnly", $true)
                    #-- Set up the credential objects --#
                    if ($PSCmdlet.ParameterSetName.Contains('ConfigPlain')) {
                        $ConfigurationCredentials = ConvertFrom-PlainCredentials -User $ConfigurationUser -Password $ConfigurationPassword
                        $ArgList.Add("ConfigurerCredential", $ConfigurationCredentials)
                        $ArgList.Remove("ConfigurationUser")
                        $ArgList.Remove("ConfigurationPassword")
                    }
                    if ($PSCmdlet.ParameterSetName.Contains('ServicePlain')) {
                        $ServiceCredentials = ConvertFrom-PlainCredentials -User $ServiceUser -Password $ServicePassword
                        $ArgList.Add("ServiceCredential", $ServiceCredentials)
                        $ArgList.Remove("ServiceUser")
                        $ArgList.Remove("ServicePassword")
                    }
                    $ret = & $cmdlet @ArgList
                    $ret = $ret.Split("`r`n", [System.StringSplitOptions]::RemoveEmptyEntries)[0]
                    Write-LogText $ret.Trim() -TrackTime:$TrackTime.IsPresent
                    $ret = if ($ret -notmatch $match) { $true } else { $false }
                } else {
                    Write-Warning (Get-LogText "ReportOnly functionality not available - assuming database needs an upgrade" -TrackTime:$TrackTime.IsPresent)
                    $ret = $true
                }
            }
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        $msg = "The database "
        $msg += if (-not $ret) { "does not need " } else { "does need " }
        $msg += "an upgrade"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

function Test-InstanceVariance {
    # .ExternalHelp AppSenseDesktopNowConfiguration.psm1-help.xml
    [CmdletBinding(DefaultParameterSetName='UseCurrent')]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlain')]
        [string]$ConfigurationUser = [string]::Empty,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigPlain')]
        [string]$ConfigurationPassword = [string]::Empty,

        [Parameter(Mandatory=$true, ParameterSetName='ConfigCreds')]
        [System.Management.Automation.PSCredential]$ConfigurationCredentials = [PSCredential]::Empty,

        [Parameter(Mandatory=$false)]
        [switch]$ConfigurerSqlAuthentication,

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
            Write-LogText "Testing if there are any variances for the connected product" -TrackTime:$TrackTime.IsPresent
            $cmdlet = "Get-ApsVariance"
            if (Test-CmdletAvailablilty -CmdletName $cmdlet -TrackTime:$TrackTime.IsPresent) {
                $ArgList = @{} + $PSBoundParameters
                #-- Set up the credential objects --#
                if ($PSCmdlet.ParameterSetName.Contains('ConfigPlain')) {
                    $ConfigurerCredential = ConvertFrom-PlainCredentials -User $ConfigurationUser -Password $ConfigurationPassword
                    $ArgList.Remove("ConfigurationUser")
                    $ArgList.Remove("ConfigurationPassword")
                }
                if ($PSCmdlet.ParameterSetName.Contains('ConfigCreds')) {
                    $ConfigurerCredential = $ConfigurationCredentials
                    $ArgList.Remove("ConfigurationCredentials")
                }
                if ($PSCmdlet.ParameterSetName -ne 'UseCurrent') { $ArgList.Add("ConfigurerCredential", $ConfigurerCredential) }
                $ArgList.Remove("TrackTime")
                $variances = & $cmdlet @ArgList
                $ret = if ($variances.Count) { $true } else { $false }
            }
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        $msg = if ($ret) { $variances.Count.ToString() } else { "No" }
        $msg += if ($variances.Count -eq 1) {" variance was " } else { " variances were " }
        $msg += "found"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

function Repair-InstanceVariance {
    # .ExternalHelp AppSenseDesktopNowConfiguration.psm1-help.xml
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
            $msg = "Attempting to repair any variances for the connected product"
            Write-LogText $msg -TrackTime:$TrackTime.IsPresent
            $cmdlet = "Repair-ApsVariance"
            if (Test-CmdletAvailablilty -CmdletName $cmdlet -TrackTime:$TrackTime.IsPresent) {
                $ArgList = @{'All'=$true} + $PSBoundParameters
                $ArgList.Remove("TrackTime")
                & $cmdlet @ArgList
                $ret = -not (Test-AppSenseDesktopNowVariance -TrackTime:$TrackTime.IsPresent)
            }
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        $msg = "Variances were "
        $msg += if (-not $ret) { "not " } else { "" }
        $msg += "repaired successfully"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

function Test-InstanceEncryptionKey {
    # .ExternalHelp AppSenseDesktopNowConfiguration.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$DatabaseServer,

        [Parameter(Mandatory=$false)]
        [string]$DatabaseName,

        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]$ConfigurerCredential,

        [Parameter(Mandatory=$false)]
        [switch]$ConfigurerSqlAuthentication,

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
            $cmdlet = "Test-AmcEncryptionKeyHash"
            if (Test-CmdletAvailablilty -CmdletName $cmdlet -TrackTime:$TrackTime.IsPresent) {
                $ArgList = @{} + $PSBoundParameters
                $ArgList.Remove("TrackTime")
                Write-LogText "Testing for the instance encryption key" -TrackTime:$TrackTime.IsPresent
                $ret = & $cmdlet @ArgList
            }
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        $msg = "Instance encryption key was "
        $msg += if (-not $ret) { "not " }
        $msg += "found"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

function Set-InstanceEncryptionKey {
    # .ExternalHelp AppSenseDesktopNowConfiguration.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$DatabaseServer,

        [Parameter(Mandatory=$false)]
        [string]$DatabaseName,

        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]$ConfigurerCredential,

        [Parameter(Mandatory=$false)]
        [switch]$ConfigurerSqlAuthentication,

        [Parameter(Mandatory=$false)]
        [switch]$DoNotForce,

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
            $cmdlet = "Set-AmcEncryptionKeyHash"
            if (Test-CmdletAvailablilty -CmdletName $cmdlet -TrackTime:$TrackTime.IsPresent) {
                $ArgList = @{} + $PSBoundParameters
                $ArgList.Remove("TrackTime")
                $ArgList.Add("Force", -not $DoNotForce.IsPresent)
                $ArgList.Remove("DoNotForce")
                Write-LogText "Setting the AMC encryption key" -TrackTime:$TrackTime.IsPresent
                $ret = & $cmdlet @ArgList
                $ret = Test-InstanceEncryptionKey -Verbose:$false
            }
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        $msg = "Instance encryption key was "
        $msg += if (-not $ret) { "not " }
        $msg += "set successfully"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

function Sync-InstanceEncryptionKey {
    # .ExternalHelp AppSenseDesktopNowConfiguration.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Password,

        [Parameter(Mandatory=$false)]
        [string]$DatabaseServer,

        [Parameter(Mandatory=$false)]
        [string]$DatabaseName,

        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]$ConfigurerCredential,

        [Parameter(Mandatory=$false)]
        [switch]$ConfigurerSqlAuthentication,

        [Parameter(Mandatory=$false)]
        [switch]$DoNotForce,

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
            $cmdlet = "Sync-AmcEncryptionKey"
            if (Test-CmdletAvailablilty -CmdletName $cmdlet -TrackTime:$TrackTime.IsPresent) {
                $ArgList = @{} + $PSBoundParameters
                $ArgList.Remove("TrackTime")
                $ArgList.Add("Force", -not $DoNotForce.IsPresent)
                $ArgList.Remove("DoNotForce")
                Write-LogText "Synchronising the instance encryption key" -TrackTime:$TrackTime.IsPresent
                $ret = & $cmdlet @ArgList
                $ret = $true
            }
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        $msg = "Instance encryption key was "
        $msg += if (-not $ret) { "not " }
        $msg += "synchronised successfully"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

function Test-InstanceTransferKey {
    # .ExternalHelp AppSenseDesktopNowConfiguration.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$DatabaseServer,

        [Parameter(Mandatory=$false)]
        [string]$DatabaseName,

        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]$ConfigurerCredential,

        [Parameter(Mandatory=$false)]
        [switch]$ConfigurerSqlAuthentication,

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
            $cmdlet = "Test-AmcEncryptionKey"
            if (Test-CmdletAvailablilty -CmdletName $cmdlet -TrackTime:$TrackTime.IsPresent) {
                $ArgList = @{} + $PSBoundParameters
                $ArgList.Remove("TrackTime")
                Write-LogText "Testing for the instance transfer key" -TrackTime:$TrackTime.IsPresent
                $ret = & $cmdlet @ArgList
            }
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        $msg = "Instance transfer key was "
        $msg += if (-not $ret) { "not " }
        $msg += "found"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

function Set-InstanceTransferKey {
    # .ExternalHelp AppSenseDesktopNowConfiguration.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Password,

        [Parameter(Mandatory=$false)]
        [string]$DatabaseServer,

        [Parameter(Mandatory=$false)]
        [string]$DatabaseName,

        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]$ConfigurerCredential,

        [Parameter(Mandatory=$false)]
        [switch]$ConfigurerSqlAuthentication,

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
            $cmdlet = "Publish-AmcEncryptionKey"
            if (Test-CmdletAvailablilty -CmdletName $cmdlet -TrackTime:$TrackTime.IsPresent) {
                $ArgList = @{} + $PSBoundParameters
                $ArgList.Remove("TrackTime")
                $ArgList.Add("Force", -not $DoNotForce.IsPresent)
                Write-LogText "Setting the instance transfer key" -TrackTime:$TrackTime.IsPresent
                $ret = & $cmdlet @ArgList
                $ret = Test-AppSenseAMCTransferKey -Verbose:$false
            }
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        $msg = "Instance transfer key was "
        $msg += if (-not $ret) { "not " }
        $msg += "set successfully"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

function Remove-InstanceTransferKey {
    # .ExternalHelp AppSenseDesktopNowConfiguration.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$DatabaseServer,

        [Parameter(Mandatory=$false)]
        [string]$DatabaseName,

        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]$ConfigurerCredential,

        [Parameter(Mandatory=$false)]
        [switch]$ConfigurerSqlAuthentication,

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
            $cmdlet = "Unpublish-AmcEncryptionKey"
            if (Test-CmdletAvailablilty -CmdletName $cmdlet -TrackTime:$TrackTime.IsPresent) {
                $ArgList = @{} + $PSBoundParameters
                $ArgList.Remove("TrackTime")
                Write-LogText "Removing the instance transfer key" -TrackTime:$TrackTime.IsPresent
                $ret = & $cmdlet @ArgList
                $ret = $true
            }
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        $msg = "Instance transfer key was "
        $msg += if (-not $ret) { "not " }
        $msg += "removed successfully"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

function Invoke-InstanceNativeCommand {
    # .ExternalHelp AppSenseDesktopNowConfiguration.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$FunctionName,

        [Parameter(Mandatory=$false)]
        [System.Collections.Hashtable]$ArgList,

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
            if ($ArgList) {
                $arg = ""
                foreach ($a in $ArgList.GetEnumerator()) {
                    $arg += "-{0} `"{1}`" " -f $a.Name, $a.Value
                }
            }
            $msg = "Executing $FunctionName "
            $msg += if ($ArgList) { $arg.Trim() } else { "with no arguments" }
            Write-LogText $msg -TrackTime:$TrackTime.IsPresent
            if ($ArgList) {
                $ret = & $FunctionName @ArgList
            } else {
                $ret = & $FunctionName
            }
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        Write-LogText "Finished executing $FunctionName" -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

function Test-CmdletAvailablilty {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$CmdletName,

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
            if (Get-Command $CmdletName -CommandType Cmdlet -ErrorAction SilentlyContinue) {
                $ret = $true
            } else {
                Throw ("$CmdletName is not available - please ensure that you are connected to a product instance")
            }
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        return $ret
    }
}

function Get-InstanceProperties {
    # .ExternalHelp AppSenseDesktopNowConfiguration.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [AppSenseDesktopNowSCU.Products]$ProductName,

        [Parameter(Mandatory=$false)]
        [string]$InstanceName,

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
            $msgInstance = if ($InstanceName) { $InstanceName } else { "default" }
            $msg = "Fetching properties for the $msgInstance instance for $ProductName"
            Write-LogText $msg -TrackTime:$TrackTime.IsPresent
            $instance = Get-ApsInstance -ProductName (Get-SCUProduct $ProductName)
            if ($InstanceName) {
                $instance = $instance | Where Name -eq $InstanceName
            } else {
                $instance = $instance | Where IsDefault
            }
            if (-not $instance) { Throw('Instance not found') }
            $ret = $instance
        } catch {
            $ret = $false
        }
    }
    End {
        $msg = if ($ret) { "Successfully retrieved " } else { "Failed to retrieve " }
        $msg += "details for instance"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

function Get-InstanceDetails {
    # .ExternalHelp AppSenseDesktopNowConfiguration.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [AppSenseDesktopNowSCU.Products]$ProductName,

        [Parameter(Mandatory=$false)]
        [string]$InstanceName,

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
            $msgInstance = if ($InstanceName) { $InstanceName } else { "default" }
            $msg = "Fetching details for the $msgInstance instance for $ProductName"
            Write-LogText $msg -TrackTime:$TrackTime.IsPresent
            $instance = Get-ApsInstance -ProductName (Get-SCUProduct $ProductName)
            if ($InstanceName) {
                $instance = $instance | Where Name -eq $InstanceName
            } else {
                $instance = $instance | Where IsDefault
            }
            if (-not $instance) { Throw('Instance not found') }
            Import-ApsInstanceModule -InstanceId $instance.InstanceId
            if (-not (Get-Command -Name Get-ApsServerDetail -ErrorAction SilentlyContinue)) {
                $msg = 'This cmdlet should is only available in v10 and above.'
                Write-Warning $msg 
                Throw($msg)
            }
            $ret = Get-ApsServerDetail
        } catch {
            $ret = $false
        }
    }
    End {
        $msg = if ($ret) { "Successfully retrieved " } else { "Failed to retrieve " }
        $msg += "details for instance"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

Export-ModuleMember -Function *-Instance*, Set-LogPath