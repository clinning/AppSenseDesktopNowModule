function New-IISWebsite {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$false)]
        [int]$Port = 80,

        [Parameter(Mandatory=$false)]
        [string]$Protocol = 'http',

        [Parameter(Mandatory=$false)]
        [string]$Bindings = [string]::Empty,

        [Parameter(Mandatory=$false)]
        [ValidateScript({[System.IO.Path]::IsPathRooted($_)})]
        [string]$PhysicalPath,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
    }
    Process {
        $ret = $false
        try {
            if (Import-IISModule -TrackTime:$TrackTime.IsPresent) {
                Write-LogText "Creating the `"$Name`" website" -TrackTime:$TrackTime.IsPresent
                $NewItemArgList = @{'Path'="iis:\Sites\$Name"; 'Bindings'=@{protocol=$Protocol; bindingInformation="*:$($Port):$($Bindings)"}}
                if (-not $PhysicalPath) { $PhysicalPath = Join-Path -Path (Get-IISInetPub) -ChildPath $Name }
                if (-not (Test-Path -Path $PhysicalPath)) {
                    Write-LogText "PhysicalPath doesn't exist so creating `"$PhysicalPath`"" -TrackTime:$TrackTime.IsPresent
                    New-Item -Path $PhysicalPath -Type Directory -Force | Out-Null
                }
                if ($PhysicalPath) { $NewItemArgList.Add('PhysicalPath', $PhysicalPath) }
                New-Item @NewItemArgList | Out-Null
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

function Test-IISWebSite {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
    }
    Process {
        $ret = $false
        try {
            if (Import-IISModule -TrackTime:$TrackTime.IsPresent) {
                Write-LogText "Searching for website `"$Name`"" -TrackTime:$TrackTime.IsPresent
                $ret = Test-Path iis:\Sites\$Name
            }
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        $msg = "Website `"$Name`" was "
        $msg += if ($ret) { "found" } else { "not found" }
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

#https://support.microsoft.com/en-us/kb/2015129
function Test-IISWASNET4Compatibility {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        $ret = $false
    }
    Process {
        try {
            Write-LogText "Checking if IIS WAS is .NET Framework 4 compatible" -TrackTime:$TrackTime.IsPresent
            [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.Web.Administration") | Out-Null
            $iis = New-Object "Microsoft.Web.Administration.ServerManager"
            $config = $iis.GetApplicationHostConfiguration()
            $section = $config.GetSection("system.webServer/modules")
            $setting = $section.GetCollection() | Where { $_.Attributes.value -eq "ServiceModel" }
            if ($setting.Attributes["preCondition"].value -match ",runtimeVersionv2.0") { $ret = $true }
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        $msg = "IIS WAS is "
        $msg += if (-not $ret) { "not " } else { "" }
        $msg += "compatible"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

#https://support.microsoft.com/en-us/kb/2015129
function Repair-IISWASNET4Compatibility {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        $ret = $false
    }
    Process {
        try {
            Write-LogText "Repairing IIS WAS .NET Framework 4 compatibility" -TrackTime:$TrackTime.IsPresent
            $e = Start-ExternalProcess -Command "$env:WinDir\Microsoft.NET\Framework64\v4.0.30319\aspnet_regiis.exe" -ArgumentList @("/iru") -ReturnExitCode -TrackTime:$TrackTime.IsPresent
            if ($e -ne 0) { Throw("Error $e repairing IIS WAS .NET Framework 4 compatibility") }
            $ret = Test-IISWASNET4Compatibility -TrackTime:$TrackTime.IsPresent -Verbose:$false
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        $msg = "IIS WAS .NET Framework 4 compatibility was "
        $msg += if (-not $ret) { "not " } else { "" }
        $msg += "repaired"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

function Test-SQLUserExists {
    [CmdletBinding(DefaultParameterSetName='ServerLogin')]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Username,

        [Parameter(Mandatory=$false)]
        [string]$SQLServer = [System.Net.Dns]::GetHostName(),

        [Parameter(Mandatory=$false)]
        [string]$SQLInstance,

        [Parameter(Mandatory=$false, ParameterSetName='DBUser')]
        [string]$DBName,

        [Parameter(Mandatory=$false)]
        [PSCredential]$ConnectAsUserCreds,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        $ret = $false
    }
    Process {
        try {
            $sql = $SQLServer
            if ($SQLInstance) { $sql += "\$SQLInstance" }
            $msg = "Testing if $Username is a valid user of SQL on $sql"
            Write-LogText $msg -TrackTime:$TrackTime.IsPresent
            if (Import-SQLModule -TrackTime:$TrackTime.IsPresent) {
                $SQLArgs = @{} + $PSBoundParameters
                $SQLArgs.Remove('Username')
                $SQLArgs.Remove('DBName')
                $SQLArgs.Remove('TrackTime')
                $sqlConn = Get-SQLConnectionObject @SQLArgs
                $sqlSMOServer = New-Object "Microsoft.SqlServer.Management.Smo.Server" -ArgumentList $sqlConn
                if ($PSCmdlet.ParameterSetName -eq 'ServerLogin') {
                    $sqlLogins = $sqlSMOServer.Logins
                } else {
                    $db = New-Object Microsoft.SqlServer.Management.Smo.Database
                    $db = $sqlSMOServer.Databases.Item($DBName)
                    $sqlLogins = $db.Users
                }
                $ret = if ($sqlLogins | Where Name -eq $Username) { $true } else { $false }
            }
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        $msg = "$Username is "
        $msg += if (-not $ret) { "not " } else { "" }
        $msg += "a user on $sql"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

function Get-SQLUserRoles {
    [CmdletBinding(DefaultParameterSetName='ServerRoles')]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Username,

        [Parameter(Mandatory=$false)]
        [string]$SQLServer = [System.Net.Dns]::GetHostName(),

        [Parameter(Mandatory=$false)]
        [string]$SQLInstance,

        [Parameter(Mandatory=$false, ParameterSetName='DBRoles')]
        [string]$DBName,

        [Parameter(Mandatory=$false)]
        [PSCredential]$ConnectAsUserCreds,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        $ret = $false
    }
    Process {
        try {
            $sql = $SQLServer
            if ($SQLInstance) { $sql += "\$SQLInstance" }
            $msg = if ($PSCmdlet.ParameterSetName -eq 'ServerRoles') { "Getting server roles for $Username on $sql" } else { "Getting database roles for $Username in $DBName on $sql" }
            Write-LogText $msg -TrackTime:$TrackTime.IsPresent
            if (Import-SQLModule -TrackTime:$TrackTime.IsPresent) {
                $SQLArgs = @{} + $PSBoundParameters
                $SQLArgs.Remove('Username')
                $SQLArgs.Remove('DBName')
                $SQLArgs.Remove('TrackTime')
                $sqlConn = Get-SQLConnectionObject @SQLArgs
                $sqlSMOServer = New-Object "Microsoft.SqlServer.Management.Smo.Server" -ArgumentList $sqlConn
                $ret = @()
                if ($PSCmdlet.ParameterSetName -eq 'ServerRoles') {
                    $sqlRoles = $sqlSMOServer.Roles
                    foreach ($role in $sqlRoles) {
                        if ($role.EnumServerRoleMembers().Contains($Username)) { $ret += $role.Name }
                    }
                } else {
                    $db = New-Object Microsoft.SqlServer.Management.Smo.Database
                    $db = $sqlSMOServer.Databases.Item($DBName)
                    $sqlRoles = $db.Roles
                    foreach ($role in $sqlRoles) {
                        if ($role.EnumMembers().Contains($Username)) { $ret += $role.Name }
                    }
                }
            }
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        $msg = "$Username is a member of "
        $msg += if (-not $ret) { "0 roles " } else { "$($ret -join ',') " }
        $msg += if ($PSCmdlet.ParameterSetName -eq 'DBRoles') { "in $DBName " } else { "" }
        $msg += "on $sql"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

function Test-SQLUserIsValidConfigurationUser {
    [CmdletBinding(DefaultParameterSetName='ServerRoles')]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Username,

        [Parameter(Mandatory=$false)]
        [string]$SQLServer = [System.Net.Dns]::GetHostName(),

        [Parameter(Mandatory=$false)]
        [string]$SQLInstance,

        [Parameter(Mandatory=$false, ParameterSetName='DBRoles')]
        [string]$DBName,

        [Parameter(Mandatory=$false)]
        [PSCredential]$ConnectAsUserCreds,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        $ret = $false
    }
    Process {
        try {
            $sql = $SQLServer
            if ($SQLInstance) { $sql += "\$SQLInstance" }
            $msg = "Testing if $Username is a valid Configuration user "
            if ($PSCmdlet.ParameterSetName -eq 'DBRoles') { $msg += "in $DBName " }
            $msg += "on $sql"
            Write-LogText $msg -TrackTime:$TrackTime.IsPresent
            $roles = Get-SQLUserRoles @PSBoundParameters
            if ($PSCmdlet.ParameterSetName -eq 'ServerRoles') {
                if ($roles) {
                    if ($roles.Contains('sysadmin')) {
                        $ret = $true
                    } else {
                        foreach ($role in $AppSenseDefaults.SCU.DBServerRoles) {
                            if ($roles.Contains($role)) {
                                $ret = $true
                            } else {
                                $ret = $false
                                break
                            }
                        }
                    }
                }
            } else { #DBRoles
                if ($roles) {
                    foreach ($role in $AppSenseDefaults.SCU.DBRoles) {
                        if ($roles.Contains($role)) {
                            $ret = $true
                        } else {
                            $ret = $false
                            break
                        }
                    }
                }
                if (-not $ret) {
                    if (Import-SQLModule -TrackTime:$TrackTime.IsPresent) {
                        $SQLArgs = @{} + $PSBoundParameters
                        $SQLArgs.Remove('Username')
                        $SQLArgs.Remove('DBName')
                        $SQLArgs.Remove('TrackTime')
                        $sqlConn = Get-SQLConnectionObject @SQLArgs
                        $sqlSMOServer = New-Object "Microsoft.SqlServer.Management.Smo.Server" -ArgumentList $sqlConn
                        $db = New-Object Microsoft.SqlServer.Management.Smo.Database
                        $db = $sqlSMOServer.Databases.Item($DBName)
                        $mappings = $db.EnumLoginMappings() | Where LoginName -eq $Username
                        foreach ($m in $mappings) {
                            if ($m.UserName -eq 'dbo') {
                                $ret = $true
                                break
                            }
                        }
                    }
                }
            }
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        $msg = "$Username is "
        $msg += if (-not $ret) { "not " } else { "" }
        $msg += "a valid Configuration user "
        if ($PSCmdlet.ParameterSetName -eq 'DBRoles') { $msg += "in $DBName " }
        $msg += "on $sql"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

function Set-SQLUserToValidConfigurationUser {
    [CmdletBinding(DefaultParameterSetName='ServerRoles')]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Username,

        [Parameter(Mandatory=$false)]
        [string]$Password,

        [Parameter(Mandatory=$false)]
        [string]$SQLServer = [System.Net.Dns]::GetHostName(),

        [Parameter(Mandatory=$false)]
        [string]$SQLInstance,

        [Parameter(Mandatory=$false, ParameterSetName='DBRoles')]
        [string]$DBName,

        [Parameter(Mandatory=$false)]
        [PSCredential]$ConnectAsUserCreds,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        $ret = $false
    }
    Process {
        try {
            $sql = $SQLServer
            if ($SQLInstance) { $sql += "\$SQLInstance" }
            $msg = "Setting $Username to be a valid Configuration user on $sql"
            Write-LogText $msg -TrackTime:$TrackTime.IsPresent
            if (Import-SQLModule -TrackTime:$TrackTime.IsPresent) {
                $SQLArgs = @{} + $PSBoundParameters
                $SQLArgs.Remove('Username')
                $SQLArgs.Remove('DBName')
                $SQLArgs.Remove('TrackTime')
                $sqlConn = Get-SQLConnectionObject @SQLArgs
                $sqlSMOServer = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList $sqlConn
                $blnCreated = $false
                $u = $sqlSMOServer.Logins | Where Name -eq $Username
                if (-not $u) {
                    $u = New-Object Microsoft.SqlServer.Management.Smo.Login -ArgumentList $sqlSMOServer, $Username
                    if ($Username.Contains('\')) {
                        $u.LoginType = [Microsoft.SqlServer.Management.Smo.LoginType]::WindowsUser
                        $u.Create()
                    } else {
                        $u.LoginType = [Microsoft.SqlServer.Management.Smo.LoginType]::SqlLogin
                        if (-not $Password) { Throw('No password specified') }
                        $u.Create($Password)
                    }
                }
                $params = @{} + $PSBoundParameters
                $params.Remove('Password')
                $params.Remove('Verbose')
                $currentServerRoles = Get-SQLUserRoles @params -Verbose:$false
                $roles = if ($PSCmdlet.ParameterSetName -eq 'ServerRoles') {
                    foreach ($role in $AppSenseDefaults.SCU.DBServerRoles) { $u.AddToRole($role) }
                } else {
                    $db = New-Object Microsoft.SqlServer.Management.Smo.Database
                    $db = $sqlSMOServer.Databases.Item($DBName)
                    if (-not ($db.Users | Where Name -eq $Username)) {
                        $dbUser = New-Object Microsoft.SqlServer.Management.Smo.User -ArgumentList $db, $Username
                        $dbUser.Login = $Username
                        $dbUser.DefaultSchema = "dbo"
                        $dbUser.Create()
                        foreach ($role in $AppSenseDefaults.SCU.DBRoles) { $dbUser.AddToRole($role) }
                    } else {
                        Write-LogText "$Username is already a database user" -TrackTime:$TrackTime.IsPresent
                        Write-Warning "Not making any changes - not implemented yet"
                    }
                }
                $valid = Test-SQLUserIsValidConfigurationUser @params -Verbose:$false
                $ret = if ($valid) { $currentServerRoles } else { $false }
            }
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        $msg = "$Username is "
        $msg += if ($ret -ne $false) { "now " } else { "not " }
        $msg += "a valid Configuration user on $sql"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

function Remove-SQLUser {
    [CmdletBinding(DefaultParameterSetName='ServerLogin')]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Username,

        [Parameter(Mandatory=$false)]
        [string]$SQLServer = [System.Net.Dns]::GetHostName(),

        [Parameter(Mandatory=$false)]
        [string]$SQLInstance,

        [Parameter(Mandatory=$false, ParameterSetName='DBUser')]
        [string]$DBName,

        [Parameter(Mandatory=$false)]
        [PSCredential]$ConnectAsUserCreds,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        $ret = $false
    }
    Process {
        try {
            $sql = $SQLServer
            if ($SQLInstance) { $sql += "\$SQLInstance" }
            $msg = if ($PSCmdlet.ParameterSetName -eq 'ServerLogin') { "Removing $Username from $sql" } else { "Removing $Username as a user from $DBName on $sql" }
            Write-LogText $msg -TrackTime:$TrackTime.IsPresent
            if (Import-SQLModule -TrackTime:$TrackTime.IsPresent) {
                if (Test-SQLUserExists @PSBoundParameters) {
                    $SQLArgs = @{} + $PSBoundParameters
                    $SQLArgs.Remove('Username')
                    $SQLArgs.Remove('DBName')
                    $SQLArgs.Remove('TrackTime')
                    $sqlConn = Get-SQLConnectionObject @SQLArgs
                    $sqlSMOServer = New-Object "Microsoft.SqlServer.Management.Smo.Server" -ArgumentList $sqlConn
                    if ($sqlSMOServer) {
                        if ($PSCmdlet.ParameterSetName -eq 'ServerLogin') {
                            $sqlLogin = $sqlSMOServer.Logins | Where Name -eq $Username
                            if ($sqlLogin) {
                                $sqlLogin.Drop()
                                $ret = -not (Test-SQLUserExists @PSBoundParameters)
                            }
                        } else {
                            $db = New-Object Microsoft.SqlServer.Management.Smo.Database
                            $db = $sqlSMOServer.Databases.Item($DBName)
                            $sqlLogin = $db.Users | Where Name -eq $Username
                            if ($sqlLogin) {
                                $sqlLogin.Drop()
                                $ret = -not (Test-SQLUserExists @PSBoundParameters)
                            }
                        }
                    }
                }
            }
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        $msg = if ($ret) { "Successfully" } else { "Failed" }
        $msg += " removed $Username from "
        $msg += if ($PSCmdlet.ParameterSetName -eq 'DBUser') { "$DBName on $sql" } else { $sql }
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

function Reset-SQLUserRoles {
    [CmdletBinding(DefaultParameterSetName='ServerRoles')]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Username,

        [Parameter(Mandatory=$true)]
        [string[]]$Roles,

        [Parameter(Mandatory=$false)]
        [string]$SQLServer = [System.Net.Dns]::GetHostName(),

        [Parameter(Mandatory=$false)]
        [string]$SQLInstance,

        [Parameter(Mandatory=$false, ParameterSetName='DBRoles')]
        [string]$DBName,

        [Parameter(Mandatory=$false)]
        [PSCredential]$ConnectAsUserCreds,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        $ret = $false
    }
    Process {
        try {
            $sql = $SQLServer
            if ($SQLInstance) { $sql += "\$SQLInstance" }
            $msg = "Resetting roles for $Username "
            if ($PSCmdlet.ParameterSetName -eq 'DBRoles') { $msg += "in $DBName " }
            $msg += "on $sql"
            Write-LogText $msg -TrackTime:$TrackTime.IsPresent
            $params = @{} + $PSBoundParameters
            $params.Remove('TrackTime')
            $params.Remove('Roles')
            $params.Remove('Verbose')
            if (Test-SQLUserExists @params) {
                if (Import-SQLModule -TrackTime:$TrackTime.IsPresent) {
                    $SQLArgs = @{} + $PSBoundParameters
                    $SQLArgs.Remove('Username')
                    $SQLArgs.Remove('DBName')
                    $SQLArgs.Remove('Roles')
                    $SQLArgs.Remove('TrackTime')
                    $sqlConn = Get-SQLConnectionObject @SQLArgs
                    $sqlSMOServer = New-Object "Microsoft.SqlServer.Management.Smo.Server" -ArgumentList $sqlConn
                    if ($PSCmdlet.ParameterSetName -eq 'ServerRoles') {
                        $sqlRoles = $sqlSMOServer.Roles
                    } else {
                        $db = New-Object Microsoft.SqlServer.Management.Smo.Database
                        $db = $sqlSMOServer.Databases.Item($DBName)
                        $sqlRoles = $db.Roles
                    }
                    foreach ($role in $sqlRoles) {
                        if ($role.Name -ne "public") {
                            if ($Roles.Contains($role.Name)) { $role.AddMember($Username) } else { $role.DropMember($Username) }
                        }
                    }
                    $ret = $true
                }
            } else {
                Throw("$Username is not a valid login")
            }
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        $msg = "$Username has "
        $msg += if (-not $ret) { "not " } else { "" }
        $msg += "had roles "
        if ($PSCmdlet.ParameterSetName -eq 'DBRoles') { $msg += "in $DBName " }
        $msg += "on $sql reset"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

Export-ModuleMember -Function *-IIS*, *-SQL*