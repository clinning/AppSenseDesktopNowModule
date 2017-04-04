. $PSScriptRoot\requiredassemblies.ps1 @($AppSenseDefaults.ManagementServer.WebServicesDLL)
$global:MS_VER = $null
$PKG_ATTEMPTED = $false

function Connect-Server {
    # .ExternalHelp AppSenseManagementServer.psm1-help.xml
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

    try {
        $ret = $false
        $paramsURL = @{} + $PSBoundParameters
        if ($Server.Contains(':')) {
            $temp = $Server.Split(':')
            $paramsURL['Host'] = $temp[0]
            $paramsURL['Port'] = $temp[1]
        } else {
            $paramsURL['Host'] = $Server
        }
        $paramsURL = Get-MatchingCmdletParameters -Cmdlet 'New-URL' -CurrentParameters $paramsURL
        $url = New-URL @paramsURL
        $url += '/ManagementServer'
        $creds = if ($PSCmdlet.ParameterSetName -eq 'AsUser') { $Credentials } else { [System.Net.CredentialCache]::DefaultCredentials.GetCredential($url, 'Basic') }
        $user = if ($PSCmdlet.ParameterSetName -eq 'AsUser') { $creds.UserName } else { 'current user' }
        Write-LogText "Connecting to $url as $user" -TrackTime:$TrackTime.IsPresent
        [ManagementConsole.WebServices]::Connect($url, $creds)
        $global:MS_VER = New-Object System.Version(Get-ServerVersion -TrackTime:$TrackTime.IsPresent)
        if ($global:MS_VER) { $ret = $true }
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    $msg = if ($ret) { "Successfully connected " } else { "Failed to connect " }
    $msg += "to $url"
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    if ($ret -and (-not $PKG_ATTEMPTED) -and ($MyInvocation.InvocationName -ne '&')) {
        $script:PKG_ATTEMPTED = $true
        $prefix = Get-ModuleDetails -Path "$PSScriptRoot\AppSenseDesktopNowAMCPackages" -Property 'Prefix' -TrackTime:$TrackTime.IsPresent -Verbose:$false
        $cmdlet = "Connect-{0}PackageServer" -f $prefix
        if (Get-Command -Name $cmdlet -ErrorAction SilentlyContinue) { $ret = & $cmdlet @PSBoundParameters }
    }
    return $ret
}

function Get-ServerVersion {
    # .ExternalHelp AppSenseManagementServer.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        if (-not [ManagementConsole.WebServices]::Database) { Throw('Please ensure that you are connected to the Management Server') }
        Write-LogText "Retrieving AppSense Management Server version" -TrackTime:$TrackTime.IsPresent
        $ret = [ManagementConsole.WebServices]::Database.GetVersion()
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    $msg = if ($ret) { "Successfully retrieved " } else { "Failed to retrieve " }
    $msg += "AppSense Management Server version"
    if ($ret) { $msg += " ($ret)" }
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

function Get-ServerName {
    # .ExternalHelp AppSenseManagementServer.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        if (-not [ManagementConsole.WebServices]::Database) { Throw('Please ensure that you are connected to the Management Server') }
        Write-LogText "Retrieving the AppSense Management Server name" -TrackTime:$TrackTime.IsPresent
        $ret = [ManagementConsole.WebServices]::Database.GetName()
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    $msg = if ($ret) { "Successfully retrieved " } else { "Failed to retrieve " }
    $msg += "the AppSense Management Server name"
    if ($ret) { $msg += " ($ret)" }
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

function Get-ServerDetails {
    # .ExternalHelp AppSenseManagementServer.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        if (-not [ManagementConsole.WebServices]::Database) { Throw('Please ensure that you are connected to the Management Server') }
        Write-LogText "Retrieving AppSense Management Server details" -TrackTime:$TrackTime.IsPresent
        $ret = [ManagementConsole.WebServices]::Database.GetInfo().NamedValues
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    $msg = if ($ret) { "Successfully retrieved " } else { "Failed to retrieve " }
    $msg += "AppSense Management Server details"
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

function Invoke-ServerMethod {
    # .ExternalHelp AppSenseManagementServer.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$DataAccessEndpoint,

        [Parameter(Mandatory=$true)]
        [string]$MethodName,

        [Parameter(Mandatory=$false)]
        [array]$MethodArguments,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        if (-not [ManagementConsole.WebServices]::$DataAccessEndpoint) { Throw('Please ensure that you are connected to the Management Server') }
        for ($i=0; $i -lt $MethodArguments.Count; $i++) { if ($MethodArguments[$i].GetType().Name.ToLower() -eq "string") { $MethodArguments[$i] = "`"$($MethodArguments[$i])`"" } }
        $exp = "[ManagementConsole.WebServices]::{0}.{1}({2})" -f $DataAccessEndpoint, $MethodName, ($MethodArguments -join ',')
        $msg = "Executing $MethodName with "
        $msg += if ($MethodArguments) { "arguments $MethodArguments" } else { "no arguments" }
        $msg += " on the $DataAccessEndpoint endpoint"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        $ret = Invoke-Expression -Command $exp
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    $msg = if ($ret) { "Successfully executed " } else { "Failed to execute " }
    $msg += "$MethodName with "
    $msg += if ($MethodArguments) { "arguments $MethodArguments" } else { "no arguments" }
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

Export-ModuleMember -Function *-Server*, Set-LogPath