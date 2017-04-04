. $PSScriptRoot\requiredassemblies.ps1 @($AppSenseDefaults.ManagementServer.WebServicesDLL)

function Get-DeploymentGroup {
    # .ExternalHelp AppSenseDesktopNowAMCDeploymentGroups.psm1-help.xml
    [CmdletBinding(DefaultParameterSetName='All')]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName='ByDGName')]
        [string]$Name,

        [Parameter(Mandatory=$true, ParameterSetName='ByDGKey')]
        [string]$Key,

        [Parameter(Mandatory=$false)]
        [switch]$IncludeSummary,

        [Parameter(Mandatory=$false)]
        [switch]$ReturnDataSet,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        if (-not [ManagementConsole.WebServices]::Groups) { Throw('Please ensure that you are connected to the Management Server') }
        Write-LogText "Retrieving Deployment Groups" -TrackTime:$TrackTime.IsPresent
        if ($PSCmdlet.ParameterSetName -ne 'ByDGKey') {
            $dg = [ManagementConsole.WebServices]::Groups.GetGroups($IncludeSummary.IsPresent)
            if ($dg -and $PSCmdlet.ParameterSetName -eq 'ByDGName') {
                Write-LogText "Filtering for $Name" -TrackTime:$TrackTime.IsPresent
                $grp = $dg.Groups | Where Name -eq $Name
                if ($grp) {
                    $dg = New-Object ManagementConsole.GroupsWebService.GroupsDataSet
                    foreach ($g in $grp) { [void]$dg.Groups.ImportRow($g) }
                } else {
                    $dg = $false
                }
            }
        } else {
            $dg = [ManagementConsole.WebServices]::Groups.GetGroupFromKey($Key, $IncludeSummary.IsPresent)
        }
        $n = 0
        if ($dg) {
            if (-not $ReturnDataSet.IsPresent) {
                $ret = $dg.Groups
                $n = $ret.Count
            } else {
                $ret = $dg
                $n = $ret.Groups.Count
            }
        }
        if (-not $ret) { $ret = $false }
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    $msg = "$n Deployment Group"
    if ($n -ne 1) { $msg += "s" }
    $msg += " match"
    if ($n -eq 1) { $msg += "es" }
    $msg += " the specified criteria"
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

Export-ModuleMember -Function *-DeploymentGroup*, Set-LogPath