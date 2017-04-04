function ConvertFrom-TimeToLocal {
    Param(
        [Parameter(Mandatory=$true)]
        [DateTime]$datetime
    )
    Return [System.TimeZoneInfo]::ConvertTime($datetime, [System.TimeZoneInfo]::Local, (Get-AppSenseManagementServerTimeZone))
}

function Import-ActiveDirectoryModule {
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
            $moduleName = 'ActiveDirectory'
            if (-not (Test-ModuleLoaded -ModuleName $moduleName -TrackTime:$TrackTime.IsPresent)) {
                if (Test-ModuleAvailability -ModuleName $moduleName -TrackTime:$TrackTime.IsPresent) {
                    Write-LogText "Importing $moduleName module" -TrackTime:$TrackTime.IsPresent
                    Import-Module $moduleName -Verbose:$false
                    $ret = $true
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
