function Import-IISModule {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Begin {
        if (Get-Command Get-CallerPreference -CommandType Function -ErrorAction SilentlyContinue) {
            Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        }
    }
    Process {
        $IIS_MODULE = "WebAdministration"
        $ret = $false
        try {
            if (-not (Test-ModuleLoaded -ModuleName $IIS_MODULE -TrackTime:$TrackTime.IsPresent)) {
                if (Test-ModuleAvailability -ModuleName $IIS_MODULE -TrackTime:$TrackTime.IsPresent) {
                    Write-LogText "Importing $IIS_MODULE" -TrackTime:$TrackTime.IsPresent
                    Import-Module $IIS_MODULE -Verbose:$false
                    $ret = $true
                } else {
                    Throw("$IIS_MODULE not available")
                }
            } else {
                $ret = $true
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

function Get-IISInetPub {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Begin {
        if (Get-Command Get-CallerPreference -CommandType Function -ErrorAction SilentlyContinue) {
            Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        }
        $ret = $false
    }
    Process {
        try {
            $REG_PATH = "Registry::HKLM\Software\Microsoft\InetStp"
            $REG_VALUE = "PathWWWRoot"
            $ret = Split-Path -Path ((Get-ItemProperty -Path $REG_PATH -Name $REG_VALUE).$REG_VALUE) -Parent
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        return $ret
    }
}

function Import-SQLModule {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Begin {
        if (Get-Command Get-CallerPreference -CommandType Function -ErrorAction SilentlyContinue) {
            Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        }
    }
    Process {
        $SMO = @("Microsoft.SqlServer.Smo", "Microsoft.SqlServer.ConnectionInfo")
        $ret = $false
        try {
            foreach ($assembly in $SMO) {
                if (-not (Test-DLLLoaded -DLLName $assembly -TrackTime:$TrackTime.IsPresent)) {
                    #-- grab full details from the registry --#
                    $smoReg = (Get-ItemProperty -Path "Registry::HKLM\SOFTWARE\Classes\Installer\Assemblies\Global" -Name "$assembly,*" -ErrorAction SilentlyContinue)
                    if (-not $smoReg) { Throw('Unable to load the required SQL Server SMO Libraries.  These are available as part of the SQL Server Feature Pack.') }
                    $smoAssemblyName = ($smoReg.PSObject.Properties | Where Name -like "$assembly*").Name
                    if (-not $smoAssemblyName) { Throw("$assembly not found") }
                    Write-LogText "Loading $assembly" -TrackTime:$TrackTime.IsPresent
                    Add-Type -AssemblyName $smoAssemblyName
                    $ret = $true
                } else {
                    $ret = $true
                }
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

function Get-SQLConnectionObject {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$SQLServer = [System.Net.Dns]::GetHostName(),

        [Parameter(Mandatory=$false)]
        [string]$SQLInstance,

        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]$ConnectAsUserCreds
    )

    $sql = $SQLServer
    if ($SQLInstance) { $sql += "\$SQLInstance" }
    $sqlConn = New-Object "Microsoft.SqlServer.Management.Common.ServerConnection"
    if ($ConnectAsUserCreds) {
        if ($ConnectAsUserCreds.UserName.Contains('\')) {
            $t = $ConnectAsUserCreds.UserName.Split('\')
            $ConnectAsUserCreds = New-Object System.Management.Automation.PSCredential -ArgumentList ("{0}@{1}" -f $t[1], $t[0]), $ConnectAsUserCreds.Password
        }
        if ($ConnectAsUserCreds.UserName.Contains('@')) {
            $sqlConn.LoginSecure = $true
            $sqlConn.ConnectAsUser = $true
            $sqlConn.ConnectAsUserName = $ConnectAsUserCreds.UserName
            $sqlConn.ConnectAsUserPassword = Get-UserCredentialsPassword -Credentials $ConnectAsUserCreds
        } else {
            $sqlConn.LoginSecure = $false
            $sqlConn.Login = $ConnectAsUserCreds.UserName
            $sqlConn.SecurePassword = $ConnectAsUserCreds.Password
        }
    } else {
        $sqlConn.LoginSecure = $true
    }
    $sqlConn.ServerInstance = $sql
    return $sqlConn
}