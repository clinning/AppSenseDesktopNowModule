function Add-Ancillary {
    # .ExternalHelp AppSenseDesktopNowAncillary.psm1-help.xml
    Param(
        [Parameter(Mandatory=$true)]
        [string]$AncillaryPath,

        [Parameter(Mandatory=$false)]
        [string[]]$ArgList,

        [Parameter(Mandatory=$false)]
        [switch]$UseShell,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        $wd = Split-Path -Path $AncillaryPath -Parent
        $e = Start-ExternalProcess -Command $AncillaryPath -ArgumentList $ArgList -WorkingDirectory $wd -ReturnExitCode -UseShell:$UseShell.IsPresent -TrackTime:$TrackTime.IsPresent
        $ret = if ($e -ne 0) { $false } else { $true }
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    return $ret
}

Export-ModuleMember -Function Add-Ancillary, Set-LogPath