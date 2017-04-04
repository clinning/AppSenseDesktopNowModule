Add-Type -TypeDefinition @"
    namespace AppSenseDesktopNowSCU {
        public enum Products { ManagementCenter, PersonalizationServerOnly, BrowserInterfaceOnly, PersonalizationAndBrowserInterface, PersOpsOnly, PersonalizationAndPersOps }
        public enum WebsiteAuthenticationType { Anonymous, Windows} //Basic, Digest, Unsupported }
    }
"@

function Get-SCUProduct([AppSenseDesktopNowSCU.Products]$p) {
    $prods = @('AppSense Management Server', 'AppSense Personalization Server')
    $p = if ($p -ge 2) { 1 } else { 0 }
    return $prods[$p]
}

function Get-SCUProductInstallMode([AppSenseDesktopNowSCU.Products]$p) {
    $mode = @('', 'EMP', 'EMBI', 'ALL', 'PWC', 'ALL')
    return $mode[$p]
}

function Import-AppSenseInstancesModule {
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
            if (-not (Test-ModuleLoaded -ModuleName $AppSenseDefaults.SCU.ModuleName -TrackTime:$TrackTime.IsPresent)) {
                if (Test-ModuleAvailability -ModuleName $AppSenseDefaults.SCU.ModuleName -TrackTime:$TrackTime.IsPresent) {
                    Write-LogText "Importing $($AppSenseDefaults.SCU.ModuleName)" -TrackTime:$TrackTime.IsPresent
                    Import-Module $AppSenseDefaults.SCU.ModuleName -Verbose:$false -Scope Global
                    $ret = $true
                } else {
                    Throw("$($AppSenseDefaults.SCU.ModuleName) not available")
                }
            } else {
                $ret = $true
            }
        } catch {
            $ret = $false
        }
    }
    End {
        return $ret
    }
}

function Import-AppSenseSCPModule {
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
            if (-not (Test-ModuleLoaded -ModuleName $AppSenseDefaults.SCP.ModuleName -TrackTime:$TrackTime.IsPresent)) {
                if (Test-ModuleAvailability -ModuleName $AppSenseDefaults.SCP.ModuleName -TrackTime:$TrackTime.IsPresent) {
                    Write-LogText "Importing $($AppSenseDefaults.SCP.ModuleName)" -TrackTime:$TrackTime.IsPresent
                    Import-Module $AppSenseDefaults.SCP.ModuleName -Verbose:$false -Scope Global
                    $ret = $true
                } else {
                    Throw("$($AppSenseDefaults.SCP.ModuleName) not available")
                }
            } else {
                $ret = $true
            }
        } catch {
            $ret = $false
        }
    }
    End {
        return $ret
    }
}