. $PSScriptRoot\requiredassemblies.ps1 @($AppSenseDefaults.PersonalizationServer.ProxyDLL)
$global:EMPS_CONNECTION = $null

<##################################################################################################################
    OnRemove handler - used in order to ensure that we always diconnect from the server.
    This also applies even if the module was loaded as a nested one.
##################################################################################################################>
$ExecutionContext.SessionState.Module.OnRemove = {
    Disconnect-Server
}

function Connect-Server {
    # .ExternalHelp AppSenseDesktopNowEMPServer.psm1-help.xml
    [CmdletBinding(DefaultParameterSetName='AsUser')]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Server,

        [Parameter(Mandatory=$true, ParameterSetName='AsUser')]
        [PSCredential]$Credentials,

        [Parameter(Mandatory=$false)]
        [uint32]$Port = 0,

        [Parameter(Mandatory=$false)]
        [switch]$UseHTTPS,

        [Parameter(Mandatory=$true, ParameterSetName='AsCurrentUser')]
        [switch]$UseCurrentUser,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    $ret = $false
    try {
        $paramsURL = @{'NoProtocol'=$true} + $PSBoundParameters
        if ($Server.Contains(':')) {
            $temp = $Server.Split(':')
            $paramsURL['Host'] = $temp[0]
            $paramsURL['Port'] = $temp[1]
        } else {
            $paramsURL['Host'] = $Server
        }
        $paramsURL = Get-MatchingCmdletParameters -Cmdlet 'New-URL' -CurrentParameters $paramsURL
        $url = New-URL @paramsURL
        $msg = "Connecting to Personalization Server $url as "
        $msg += if ($UseCurrentUser) { "current user" } else { $Credentials.Username }
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        $global:EMPS_CONNECTION = if ($UseCurrentUser.IsPresent) { [PSProxy]::Connect($url, $UseHTTPS.IsPresent) } else { [PSProxy]::Connect($url, $UseHTTPS.IsPresent, $Credentials.Username, (Get-UserCredentialsPassword -Credentials $Credentials)) }
        if ($global:EMPS_CONNECTION) { $ret = $true }
    } catch {
        $ret = $false
    }
    $msg = if ($ret) { "Successfully" } else { "Failed to" }
    $msg += " connect"
    $msg += if ($ret) { "ed " } else { " " }
    $msg += "to $url as "
    $msg += if ($UseCurrentUser) { "current user" } else { $Credentials.Username }
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

function Disconnect-Server {
    # .ExternalHelp AppSenseDesktopNowEMPServer.psm1-help.xml
    [CmdletBinding(DefaultParameterSetName='AsUser')]
    Param(
        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    $ret = $false
    try {
        if ($global:EMPS_CONNECTION) {
            $url = New-Object System.Uri($global:EMPS_CONNECTION.Endpoint.Address)
            $url = $url.GetLeftPart([System.UriPartial]::Authority)
            Write-LogText "Disconnecting from Personalization Server ($url)" -TrackTime:$TrackTime.IsPresent
            $global:EMPS_CONNECTION.Close()
            $global:EMPS_CONNECTION = $null
        }
        $ret = $true
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
}

<##################################################################################################################
    Aim:        To execute any given method on the EMPS API.
    Notes:      Executes in a way that needs strong types on variables.  This will take care of that as well as
                determining if any variables are passed by reference and therefore return a value.
    Returns:    If there are no reference variables then the return is as was from the API.
                If there are reference variables then the return is a hashtable containing: -
                    APIReturn = the return as was from the API
                    <variable name>[n] = the return that would have been in the reference variable with it's name
                                         as the key
##################################################################################################################>
function Invoke-ServerMethod {
    # .ExternalHelp AppSenseDesktopNowEMPServer.psm1-help.xml
    [CmdletBinding(DefaultParameterSetName='AsUser')]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$false)]
        [array]$Arguments,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        if (-not $global:EMPS_CONNECTION) { Throw('Please ensure that you are connected to the Personalization Server') }
        $params = $global:EMPS_CONNECTION | Get-Member -Name $Name | Select -ExpandProperty Definition
        $r = [regex]"$Name\((.*)\),"
        $params = $r.match($params).Groups[1].Value.Split(",")
        $vnames = @{}
        for($i=0; $i -le $params.length - 1; $i++) {
            $pt = $params[$i].Trim().Split(' ')
            if ($pt[0] -eq '[ref]') {
                $vnames.Add($pt[2], $i)
                $pt = $pt[1]
            } else {
                $pt = $pt[0]
            }
            if ($Arguments) {
                if ($Arguments[$i].GetType().Name.ToLower() -ne $pt.ToLower()) { #need to be strong typed so let's take care of that
                    $Arguments[$i] = if ($pt.EndsWith('[]')) { New-Object $pt 0 } else { New-Object $pt $Arguments[$i] } #dimension and cast variables
                    $Arguments[$i] = $Arguments[$i].PSObject.BaseObject #unwrap the variable
                }
            }
        }
        $ret = $global:EMPS_CONNECTION.GetType().GetMethod($Name).Invoke($global:EMPS_CONNECTION, $Arguments)
        if ($vnames.Count) {
            $ret = @{"APIReturn"=$ret}
            foreach ($v in $vnames.GetEnumerator()) { $ret.Add($v.Key, $Arguments[$v.Value]) }
        }
        if (-not $ret) { $ret = $false }
    } catch {
        $ret = $false
    }
    return $ret
}

Export-ModuleMember -Function *-Server*, Set-LogPath