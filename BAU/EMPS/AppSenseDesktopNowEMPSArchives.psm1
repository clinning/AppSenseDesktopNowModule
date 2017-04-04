function Restore-Archive {
    # .ExternalHelp AppSenseDesktopNowEMPSArchives.psm1-help.xml
    [CmdletBinding(DefaultParameterSetName='All')]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$PersonalizationGroup,

        [Parameter(Mandatory=$true)]
        [string]$User,

        [Parameter(Mandatory=$false)]
        [string]$Application,

        [Parameter(Mandatory=$true, ParameterSetName='ClosestTo')]
        [datetime]$ClosestTo,

        [Parameter(Mandatory=$true, ParameterSetName='ProtectedArchive')]
        [switch]$ProtectedOnly,

        [Parameter(Mandatory=$true, ParameterSetName='LatestArchive')]
        [switch]$LatestOnly,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        if (-not $global:EMPS_CONNECTION) { Throw('Please ensure that you are connected to the Personalization Server') }
        $ret = $false
        $params = @{} + $PSBoundParameters
        $params = Get-MatchingCmdletParameters -Cmdlet 'Get-Archive' -CurrentParameters $params
        $a = Get-Archive @params
        if ($a) {
            Write-LogText "Attempting to restore $Application for $User in $PersonalizationGroup to $($a.Archives[0].ArchiveDate)" -TrackTime:$TrackTime.IsPresent
            $ret = -not $global:EMPS_CONNECTION.RestoreArchive($a.Archives[0].ArchiveID)
        }
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    $msg = if ($ret) { "Successfully restored " } else { "Failed to restore " }
    $msg += "archive"
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

function Get-Archive {
    # .ExternalHelp AppSenseDesktopNowEMPSArchives.psm1-help.xml
    [CmdletBinding(DefaultParameterSetName='All')]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$PersonalizationGroup,

        [Parameter(Mandatory=$true)]
        [string]$User,

        [Parameter(Mandatory=$false)]
        [string]$Application,

        [Parameter(Mandatory=$true, ParameterSetName='ClosestTo')]
        [datetime]$ClosestTo,

        [Parameter(Mandatory=$true, ParameterSetName='ProtectedArchive')]
        [switch]$ProtectedOnly,

        [Parameter(Mandatory=$true, ParameterSetName='LatestArchive')]
        [switch]$LatestOnly,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        if (-not $global:EMPS_CONNECTION) { Throw('Please ensure that you are connected to the Personalization Server') }
        $ret = $false
        $params = @{} + $PSBoundParameters
        $params = Get-MatchingCmdletParameters -Cmdlet 'Get-ArchiveReport' -CurrentParameters $params
        $ret = Get-ArchiveReport @params
        if ($Application) { $ret = $ret | Where Application -eq $Application }
        if (-not $ret) { Throw 'No matching applications found' }
        if ($PSCmdlet.ParameterSetName -ne 'All') { Write-LogText "Filtering archive report" -TrackTime:$TrackTime.IsPresent }
        if ($PSCmdlet.ParameterSetName -eq 'LatestArchive') {
            $a = $ret.Archives | Sort-Object ArchiveDate -Descending | Select -First 1
            $ret.Archives = @($a)
        }
        if ($PSCmdlet.ParameterSetName -eq 'ClosestTo') {
            $a = $ret.Archives | Where ArchiveDate -le $ClosestTo | Sort-Object ArchiveDate -Descending | Select -First 1
            $ret.Archives = @($a)
        }
        if ($PSCmdlet.ParameterSetName -eq 'ProtectedArchive') {
            $a = $ret.Archives | Where IsProtected -eq $true
            $ret.Archives = @($a)
        }
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    $n = if ($ret) { $ret.Archives.Count } else { 0 }
    $msg = "$n archive"
    if ($n -ne 1) { $msg += "s" }
    $msg += " match"
    if ($n -eq 1) { $msg += "es" }
    $msg += " the specified criteria"
    if (-not $Application) { $msg += " across $($ret.Count) applications" }
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

function Get-ArchiveReport {
    # .ExternalHelp AppSenseDesktopNowEMPSArchives.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$PersonalizationGroup,

        [Parameter(Mandatory=$true)]
        [string]$User,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        if (-not $global:EMPS_CONNECTION) { Throw('Please ensure that you are connected to the Personalization Server') }
        if (-not $User.Contains('\')) { Throw('Usernames must be specified as DOMAIN\Username') }
        $msg = "Retrieving archive report for $User"
        if ($PersonalizationGroup) { $msg += " in $PersonalizationGroup" }
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        $func = 'FetchArchiveReport'
        $paramsFetch = Test-APIFunctionAvailable -ConnectionObject $global:EMPS_CONNECTION -Name $func
        if ($paramsFetch) {
            $r = [regex]"$func\((.*)\),"
            $paramsFetch = $r.match($paramsFetch).Groups[1].Value.Split(",")
            $paramsFetch = $paramsFetch | % { $_.Trim() }
            if ($paramsFetch -match "\sUserGroupName$") {
                $ret = $global:EMPS_CONNECTION.$func($PersonalizationGroup, $User)
            } else {
                $ret = $global:EMPS_CONNECTION.$func($User)
            }
        }
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    $msg = if ($ret) { "Successfully retrieved " } else { "Failed to retrieve " }
    $msg += "archive report"
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

Export-ModuleMember -Function *-Archive*, Set-LogPath