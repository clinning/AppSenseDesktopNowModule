Param(
    [Parameter(Mandatory=$true)]
    [string]$Server,

    [Parameter(Mandatory=$false)]
    [uint32]$Port = 0,

    [Parameter(Mandatory=$true, ParameterSetName='AsUserClosestTo')]
    [Parameter(Mandatory=$true, ParameterSetName='AsUserProtectedOnly')]
    [Parameter(Mandatory=$true, ParameterSetName='AsUserLatestOnly')]
    [PSCredential]$Credentials,

    [Parameter(Mandatory=$false)]
    [switch]$UseHTTPS,

    [Parameter(Mandatory=$true, ParameterSetName='AsCurrentUserClosestTo')]
    [Parameter(Mandatory=$true, ParameterSetName='AsCurrentUserProtectedOnly')]
    [Parameter(Mandatory=$true, ParameterSetName='AsCurrentUserLatestOnly')]
    [switch]$UseCurrentUser,

    [Parameter(Mandatory=$false)]
    [string]$PersonalizationGroup,

    [Parameter(Mandatory=$true)]
    [string]$User,

    [Parameter(Mandatory=$true)]
    [string]$Application,

    [Parameter(Mandatory=$true, ParameterSetName='AsUserClosestTo')]
    [Parameter(Mandatory=$true, ParameterSetName='AsCurrentUserClosestTo')]
    [datetime]$ClosestTo,

    [Parameter(Mandatory=$true, ParameterSetName='AsUserProtectedOnly')]
    [Parameter(Mandatory=$true, ParameterSetName='AsCurrentUserProtectedOnly')]
    [switch]$ProtectedOnly,

    [Parameter(Mandatory=$true, ParameterSetName='AsUserLatestOnly')]
    [Parameter(Mandatory=$true, ParameterSetName='AsCurrentUserLatestOnly')]
    [switch]$LatestOnly
)

<###########################################################################################
    Change the below lines to ensure that the path to the module is correct.
    If the script is not being executed on an EMP Server then set $global:EMPS_PROXY_PATH
    to the path that contains the PSProxy4.dll
###########################################################################################>
$modPath = Split-Path -Path (Get-Location)
Import-Module "$modPath\BAU\EMPS\AppSenseDesktopNowEMPS" -Force

<###########################################################################################
    Shouldn'y need to change anything below here
###########################################################################################>
if ($PSCmdlet.ParameterSetName.Contains('AsCurrentUser')) {
    $conn = Connect-AppSensePersonalizationServer -Server $Server -Port $Port -UseCurrentUser -UseHTTPS:$UseHTTPS.IsPresent -TrackTime -Verbose
} elseif ($PSCmdlet.ParameterSetName.Contains('AsUser')) {
    $conn = Connect-AppSensePersonalizationServer -Server $Server -Port $Port -Credentials $Credentials -UseHTTPS:$UseHTTPS.IsPresent -TrackTime -Verbose
}

if ($conn) {
    if ($PSCmdlet.ParameterSetName.Contains('ClosestTo')) {
        Restore-AppSensePersonalizationArchive -PersonalizationGroup $PersonalizationGroup -User $User -Application $Application -ClosestTo $ClosestTo -TrackTime -Verbose
    } elseif ($PSCmdlet.ParameterSetName.Contains('ProtectedOnly')) {
        Restore-AppSensePersonalizationArchive -PersonalizationGroup $PersonalizationGroup -User $User -Application $Application -ProtectedOnly -TrackTime -Verbose
    } elseif ($PSCmdlet.ParameterSetName.Contains('LatestOnly')) {
        Restore-AppSensePersonalizationArchive -PersonalizationGroup $PersonalizationGroup -User $User -Application $Application -LatestOnly -TrackTime -Verbose
    }
}