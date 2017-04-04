$MS_TZ = [System.TimeZoneInfo]::Local

function Set-ServerTimeZone {
    # .ExternalHelp AppSenseDesktopNowAMCCommon.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$TimeZoneString = [System.TimeZoneInfo]::Local,

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
            Write-LogText "Setting AppSense Management Server timezone" -TrackTime:$TrackTime.IsPresent
            $script:MS_TZ = [System.TimeZoneInfo]::FindSystemTimeZoneById($TimeZoneString)
            $ret = $true
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        $msg = "Timezone has "
        $msg += if (-not $ret) { "not " } else { "" }
        $msg += "been set successfully"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

function Get-ServerTimeZone {
    # .ExternalHelp AppSenseDesktopNowAMCCommon.psm1-help.xml
    Return $script:MS_TZ
}
