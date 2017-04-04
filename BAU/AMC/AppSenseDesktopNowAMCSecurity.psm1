. $PSScriptRoot\requiredassemblies.ps1 @($AppSenseDefaults.ManagementServer.WebServicesDLL)

function Get-SecurityConfiguredUser {
    # .ExternalHelp AppSenseDesktopNowAMCSecurity.psm1-help.xml
    [CmdletBinding(DefaultParameterSetName='All')]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName='ByUser')]
        [string]$Username,

        [Parameter(Mandatory=$true, ParameterSetName='ByKey')]
        [string]$UserKey,

        [Parameter(Mandatory=$false)]
        [switch]$GroupsOnly,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        if (-not [ManagementConsole.WebServices]::Security) { Throw('Please ensure that you are connected to the Management Server') }
        Write-LogText "Retrieving users" -TrackTime:$TrackTime.IsPresent
        $ret = [ManagementConsole.WebServices]::Security.GetUsers().Users
        if ($PSCmdlet.ParameterSetName -eq 'ByUser') {
            Write-LogText "Filtering users for $Username" -TrackTime:$TrackTime.IsPresent
            $ret = $ret | Where Name -eq $Username
        } elseif ($PSCmdlet.ParameterSetName -eq 'ByKey') {
            Write-LogText "Filtering users for $UserKey" -TrackTime:$TrackTime.IsPresent
            $ret = $ret | Where UserKey -eq $UserKey
        }
        if ($GroupsOnly.IsPresent) {
            Write-LogText "Filtering results for groups" -TrackTime:$TrackTime.IsPresent
            $ret = $ret | Where IsGroup
        }
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    $n = if ($ret) {if (-not $ret.Count) { 1 } else { $ret.Count }} else { 0 }
    $msg += "$n configured user"
    if ($n -ne 1) { $msg += "s" }
    $msg += " match"
    if ($n -eq 1) { $msg += "es" }
    $msg += " the specified criteria"
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

function Set-SecurityConfiguredUser {
    # .ExternalHelp AppSenseDesktopNowAMCSecurity.psm1-help.xml
    [CmdletBinding(DefaultParameterSetName='NTAccount')]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$Username,

        [Parameter(Mandatory=$false)]
        [string[]]$SecurityRoles,

        [Parameter(Mandatory=$false, ParameterSetName='ActiveDirectoryCurrentUser')]
        [Parameter(Mandatory=$false, ParameterSetName='ActiveDirectoryCreds')]
        [string]$ADServer,

        [Parameter(Mandatory=$false, ParameterSetName='ActiveDirectoryCreds')]
        [PSCredential]$ADCredentials,

        [Parameter(Mandatory=$false, ParameterSetName='ActiveDirectoryCurrentUser')]
        [switch]$ADUseCurrentUser,

        [Parameter(Mandatory=$false, ParameterSetName='NTAccount')]
        [switch]$IsGroup,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        if (-not [ManagementConsole.WebServices]::Security) { Throw('Please ensure that you are connected to the Management Server') }
        $paramsCU = @{'Username'=$Username; 'TrackTime'=$TrackTime.IsPresent}
        $exists = Get-SecurityConfiguredUser @paramsCU
        if (-not $exists) {
            if ($Username.Contains('\')) {
                $u = $Username.Split('\')
                $u = @{'Domain'=$u[0]; 'User'=$u[1]}
            } else {
                $u = @{'Domain'=''; 'User'=$Username}
            }
            if ($PSCmdlet.ParameterSetName.StartsWith('ActiveDirectory')) {
                $continue = $false
                if (Import-ActiveDirectoryModule -TrackTime:$TrackTime.IsPresent) {
                    $paramsAD = @{'LDAPFilter'="(|(samAccountName=$($u.User))(cn=$($u.User)))"; 'Properties'='ObjectSid','ObjectClass'}
                    if ($PSCmdlet.ParameterSetName -eq 'ActiveDirectoryCreds') {
                        $paramsAD.Add('AuthType', 'Negotiate')
                        $paramsAD.Add('Credential', $ADCredentials)
                    }
                    if (-not $ADServer) {
                        $paramsAD.Add('Server', [System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain())
                    } else {
                        $paramsAD.Add('Server', $ADServer)
                    }
                    $obj = Get-ADObject @paramsAD
                    if (-not $obj) { Throw("$Username not found in Active Directory") }
                    $u.Add('SID', $obj.ObjectSid)
                    $u.Add('IsGroup', $obj.ObjectClass -eq 'group')
                    $continue = $true
                }
            } else {
                $ntUser = New-Object System.Security.Principal.NTAccount($u.Domain, $u.User)
                try {
                    $u.Add('SID', $ntUser.Translate([System.Security.Principal.SecurityIdentifier]).Value)
                    $u.Add('IsGroup', $IsGroup.IsPresent)
                } catch [System.Security.Principal.IdentityNotMappedException] {
                    Throw("Unable to retrieve the SID for $Username")
                }
                $continue = $true
            }
            if ($continue) {
                $u.Add('UserKey', [guid]::NewGuid())
                $ret = [ManagementConsole.WebServices]::Security.CreateUser($u.UserKey, $Username, $u.SID, $u.IsGroup)
                if ($paramsCU.Keys.Contains('Verbose')) { $paramsCU.Verbose = $false } else { $paramsCU.Add('Verbose', $false) }
                if ($ret) { $userNew = Get-SecurityConfiguredUser @paramsCU }
            }
        }
        if ($exists -or $userNew) {
            $u = if ($exists) { $exists } else { $userNew }
            #-- remove existing security elements --#
            $seCurrent = [ManagementConsole.WebServices]::Security.GetSecurityElementsFromPolicy($u.PolicyKey).SecurityElements
            foreach($se in $seCurrent) {
                [void][ManagementConsole.WebServices]::Security.DeleteSecurityElement($se.SecurityElementKey, (ConvertFrom-TimeToLocal $se.ModifiedTime))
            }
            #-- add the correct security elements now --#
            if ($SecurityRoles) {
                $rolesAvailable = Get-SecurityRole -Type Server -TrackTime:$TrackTime.IsPresent -Verbose:$false
                foreach ($role in $SecurityRoles) {
                    $r = $rolesAvailable | Where Name -eq $role
                    if ($r) { [void][ManagementConsole.WebServices]::Security.CreateSecurityElement([guid]::NewGuid(), $u.PolicyKey, [ManagementConsole.SecurityWebService.ElementType]::Allow, $r.SecurityRoleKey, $u.SID) }
                }
            }
            $ret = $u.UserKey.ToString()
        }
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    $msg = if ($ret) { "Successfully " } else { "Failed to " }
    $msg += if ($exists) { "update" } else { "create" }
    $msg += if ($ret) { "d " } else { " " }
    $msg += $Username
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

function Remove-SecurityConfiguredUser {
    # .ExternalHelp AppSenseDesktopNowAMCSecurity.psm1-help.xml
    [CmdletBinding(DefaultParameterSetName='ByUser', SupportsShouldProcess=$true)]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName='ByUser')]
        [string]$Username,

        [Parameter(Mandatory=$true, ParameterSetName='ByKey')]
        [string]$UserKey,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        if (-not [ManagementConsole.WebServices]::Security) { Throw('Please ensure that you are connected to the Management Server') }
        Write-LogText "Deleting $Username from the configured users" -TrackTime:$TrackTime.IsPresent
        $paramsCU = Get-MatchingCmdletParameters -Cmdlet "Get-SecurityConfiguredUser" -CurrentParameters $PSBoundParameters
        $u = Get-SecurityConfiguredUser @paramsCU
        if ($u) {
            $target = if ($PSCmdlet.ParameterSetName -eq 'ByUser') { $Username } else { $UserKey }
            if ($PSCmdlet.ShouldProcess($target, "Delete configured user")) {
                [void][ManagementConsole.WebServices]::Security.DeleteUser($u.UserKey, (ConvertFrom-TimeToLocal $u.ModifiedTime))
                $ret = $true
            }
        }
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    if ($WhatIfPreference.IsPresent) { $ret = $true }
    $msg = if ($ret) { "Successfully deleted " } else { "Failed to delete "}
    $msg += "$Username from the configured users"
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

function Get-SecurityRole {
    # .ExternalHelp AppSenseDesktopNowAMCSecurity.psm1-help.xml
    [CmdletBinding(DefaultParameterSetName='All')]
    Param(
        [Parameter(Mandatory=$false, ParameterSetName='ByName')]
        [Parameter(Mandatory=$false, ParameterSetName='All')]
        [ManagementConsole.SecurityWebService.RoleType]$Type,

        [Parameter(Mandatory=$true, ParameterSetName='ByKey')]
        [string]$RoleKey,

        [Parameter(Mandatory=$true, ParameterSetName='ByName')]
        [string]$Name,

        [Parameter(Mandatory=$false)]
        [switch]$ReturnDataSet,

        [Parameter(Mandatory=$false, ParameterSetName='All')]
        [switch]$IncludePermissions,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        if (-not [ManagementConsole.WebServices]::Security) { Throw('Please ensure that you are connected to the Management Server') }
        Write-LogText "Retrieving security roles" -TrackTime:$TrackTime.IsPresent
        if ($Type) {
            $ret = [ManagementConsole.WebServices]::Security.GetSecurityRolesFromType($Type)
        } else {
            if ($PSCmdlet.ParameterSetName -eq 'All' -or $PSCmdlet.ParameterSetName -eq 'ByName') {
                $ret = [ManagementConsole.WebServices]::Security.GetSecurityRoles($IncludePermissions.IsPresent)
            }
        }
        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            $sr = $ret.SecurityRoles | Where Name -eq $Name
            if ($sr) {
                $ret = New-Object ManagementConsole.SecurityWebService.SecurityRolesDataSet
                foreach ($s in $sr) { [void]$ret.SecurityRoles.ImportRow($s) }
            } else {
                $ret = $false
            }
        }
        if ($RoleKey) { $ret = [ManagementConsole.WebServices]::Security.GetSecurityRoleFromKey($RoleKey) }
        if (-not $ReturnDataSet.IsPresent) {
            $ret = $ret.SecurityRoles
            $n = $ret.Count
        } else {
            $n = $ret.SecurityRoles.Count
        }
        if (-not $ret) { $ret = $false }
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    $msg += "$n security role"
    if ($n -ne 1) { $msg += "s" }
    $msg += " match"
    if ($n -eq 1) { $msg += "es" }
    $msg += " the specified criteria"
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

function Set-SecurityServerRole {
    # .ExternalHelp AppSenseDesktopNowAMCSecurity.psm1-help.xml
    [CmdletBinding(DefaultParameterSetName='ServerNew', SupportsShouldProcess=$true)]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true, ParameterSetName='ServerNew')]
        [ManagementConsole.SecurityWebService.ServerPermissions[]]$ServerPermissions,

        [Parameter(Mandatory=$true, ParameterSetName='ObjectNew')]
        [ManagementConsole.SecurityWebService.ObjectPermissions[]]$ObjectPermissions,

        [Parameter(Mandatory=$false, ParameterSetName='ServerNew')]
        [Parameter(Mandatory=$false, ParameterSetName='ObjectNew')]
        [string]$Description = [string]::Empty,

        [Parameter(Mandatory=$false, ParameterSetName='ServerUpdate')]
        [Parameter(Mandatory=$false, ParameterSetName='ObjectUpdate')]
        [string]$NewName,

        [Parameter(Mandatory=$false, ParameterSetName='ServerUpdate')]
        [Parameter(Mandatory=$false, ParameterSetName='ObjectUpdate')]
        [string]$NewDescription,

        [Parameter(Mandatory=$false, ParameterSetName='ServerUpdate')]
        [ManagementConsole.ServerPermissionFlags[]]$NewServerPermissions,

        [Parameter(Mandatory=$false, ParameterSetName='ObjectUpdate')]
        [ManagementConsole.ObjectPermissionFlags[]]$NewObjectPermissions,

        [Parameter(Mandatory=$false, ParameterSetName='ServerNew')]
        [Parameter(Mandatory=$false, ParameterSetName='ObjectNew')]
        [switch]$ReadOnly,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        if (-not [ManagementConsole.WebServices]::Security) { Throw('Please ensure that you are connected to the Management Server') }
        $paramsRole = Get-MatchingCmdletParameters -Cmdlet 'Get-SecurityRole' -CurrentParameters $PSBoundParameters
        $paramsRole.Add('ReturnDataSet', $true)
        $rt = if ($PSCmdlet.ParameterSetName.StartsWith('Server')) { [ManagementConsole.SecurityWebService.RoleType]::Server } else { [ManagementConsole.SecurityWebService.RoleType]::Object }
        $paramsRole.Add('Type', $rt)
        $exists = Get-SecurityRole @paramsRole
        if (-not $exists) {
            if ($PSCmdlet.ParameterSetName.EndsWith('New')) {
                Write-LogText "Creating role $Name" -TrackTime:$TrackTime.IsPresent
                $guid = [guid]::NewGuid()
                $permsMask = 0
                $perms = if ($PSCmdlet.ParameterSetName.StartsWith('Server')) { $ServerPermissions } else { $ObjectPermissions }
                foreach ($sp in $perms) { $permsMask = $permsMask -bor $sp }
                if ($PSCmdlet.ParameterSetName.StartsWith('Server')) {
                    $ret = [ManagementConsole.WebServices]::Security.CreateServerSecurityRole($guid, $Name, $Description, $permsMask, $ReadOnly.IsPresent)
                } else {
                    $ret = [ManagementConsole.WebServices]::Security.CreateObjectSecurityRole($guid, $Name, $Description, $permsMask, $ReadOnly.IsPresent)
                }
                if ($ret) { $ret = $guid.ToString() }
            }
        } else {
            if ($PSCmdlet.ParameterSetName.EndsWith('Update')) {
                Write-LogText "Updating role $Name" -TrackTime:$TrackTime.IsPresent
                if ($PSCmdlet.ShouldProcess($Name, "Update $($paramsRole.Type) security role")) {
                    $role = $exists.SecurityRoles | Select -First 1
                    $name = if ($NewName) { $NewName } else { $role.Name }
                    $desc = if ($NewDescription) { $NewDescription } else { $role.Description }
                    if ($NewServerPermissions -or $NewObjectPermissions) {
                        $permsMask = 0
                        $perms = if ($PSCmdlet.ParameterSetName.StartsWith('Server')) { $NewServerPermissions } else { $NewObjectPermissions }
                        foreach ($sp in $perms) { $permsMask = $permsMask -bor $sp }
                    } else {
                        $permsMask = $role.PermissionsMask
                    }
                    $sr = $exists.SecurityRoles.FindBySecurityRoleKey($role.SecurityRoleKey)
                    if ($sr) {
                        $sr.Name = $name
                        $sr.Description = $desc
                        $sr.PermissionsMask = $permsMask
                        [ManagementConsole.WebServices]::Security.ApplySecurityRoleChanges([ref]$exists)
                    }
                    $ret = $true
                }
            }
        }
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    if ($WhatIfPreference.IsPresent) { $ret = $true }
    $msg = if ($ret) { "Successfully " } else { "Failed to " }
    $msg += if ($PSCmdlet.ParameterSetName.EndsWith('Update')) { "update" } else { "create" }
    $msg += if ($ret) { "d " } else { " " }
    $msg += $Name
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

function Remove-SecurityRole {
    # .ExternalHelp AppSenseDesktopNowAMCSecurity.psm1-help.xml
    [CmdletBinding(DefaultParameterSetName='ByName', SupportsShouldProcess=$true)]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName='ByName')]
        [string]$Name,

        [Parameter(Mandatory=$true, ParameterSetName='ByKey')]
        [string]$RoleKey,

        [Parameter(Mandatory=$true, ParameterSetName='ByName')]
        [ManagementConsole.SecurityWebService.RoleType]$Type,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        if (-not [ManagementConsole.WebServices]::Security) { Throw('Please ensure that you are connected to the Management Server') }
        $target = if ($PSCmdlet.ParameterSetName -eq 'ByName') { $Name } else { $RoleKey }
        Write-LogText "Attempting to delete role $target" -TrackTime:$TrackTime.IsPresent
        $paramsRole = Get-MatchingCmdletParameters -Cmdlet 'Get-SecurityRole' -CurrentParameters $PSBoundParameters
        $exists = Get-SecurityRole @paramsRole
        if ($exists) {
            if ($exists.ReadOnly -and -not $Force.IsPresent) { Throw("$target is marked as read only") }
            if ($PSCmdlet.ShouldProcess($target, "Delete $($paramsRole.Type) security role")) {
                [ManagementConsole.WebServices]::Security.DeleteSecurityRole($exists.SecurityRoleKey, (ConvertFrom-TimeToLocal $exists.ModifiedTime))
                $ret = $true
            }
        }
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    if ($WhatIfPreference.IsPresent) { $ret = $true }
    $msg = if ($ret) { "Successfully " } else { "Failed to " }
    $msg += "delete"
    $msg += if ($ret) { "d " } else { " " }
    $msg += $target
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

Export-ModuleMember -Function *-Security*, Set-LogPath