. $PSScriptRoot\requiredassemblies.ps1 @($AppSenseDefaults.EMConfiguration.ConfigAPI)
$script:objConfiguration = $null

<#################################################################################
    Aim:        To create a new EM configuration object
    Returns:    Boolean - True on success and False on failure
#################################################################################>
function New-Configuration () {
    # .ExternalHelp AppSenseDesktopNowEMConfiguration.psm1-help.xml
    Param(
        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        $script:objConfiguration = New-Object EMConfigAPI.EMConfiguration
        $ret = if ($script:objConfiguration) { $true } else { $false }
    } catch {
        $ret = $false
    }
    $msg = if ($ret) { "Successfully" } else { "Failed to" }
    $msg += " create"
    $msg += if ($ret) { "d " } else { " " }
    $msg += "EM configuration in memory"
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

<#################################################################################
    Aim:        To save the configuration to disk
    Returns:    Boolean - True on success and False on failure
#################################################################################>
function Save-Configuration() {
    # .ExternalHelp AppSenseDesktopNowEMConfiguration.psm1-help.xml
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        if (-not $script:objConfiguration) { Throw('No in memory configuration available') }
        $script:objConfiguration.SaveConfig($Path)
        $ret = $true
    } catch {
        $ret = $false
    }
    $msg = if ($ret) { "Successfully" } else { "Failed to" }
    $msg += " save"
    $msg += if ($ret) { "d " } else { " " }
    $msg += "EM configuration to $Path"
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

<#################################################################################
    Aim:        To reset the in memory configuration to it's default state
    Returns:    Boolean - True on success and False on failure
#################################################################################>
function Clear-Configuration() {
    # .ExternalHelp AppSenseDesktopNowEMConfiguration.psm1-help.xml
    Param(
        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        if (-not $script:objConfiguration) { Throw('No in memory configuration available') }
        $script:objConfiguration.Dispose()
        $script:objConfiguration.NewConfig()
        $ret = $true
    } catch {
        $ret = $false
    }
    $msg = if ($ret) { "Successfully" } else { "Failed to" }
    $msg += " clear"
    $msg += if ($ret) { "ed " } else { " " }
    $msg += "the in memory EM configuration"
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

<##########################################################################################
    Aim:        To create a node at the given trigger point or parent
    Notes:      The available trigger points can be found in the AppSense Environment
                Manager Configuration API.pdf document
    Returns:    The GUID for the created node
                Boolean False on failure
##########################################################################################>
function New-ConfigurationNode() {
    # .ExternalHelp AppSenseDesktopNowEMConfiguration.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName='NewNormalTrigger')]
        [Parameter(Mandatory=$true, ParameterSetName='NewNormalParent')]
        [Parameter(Mandatory=$true, ParameterSetName='NewGroupTrigger')]
        [Parameter(Mandatory=$true, ParameterSetName='NewGroupParent')]
        [string]$Name,

        [Parameter(Mandatory=$true, ParameterSetName='NewNormalTrigger')]
        [Parameter(Mandatory=$true, ParameterSetName='NewGroupTrigger')]
        [EMConfigAPI.TriggerType]$Trigger,

        [Parameter(Mandatory=$true, ParameterSetName='NewNormalParent')]
        [Parameter(Mandatory=$true, ParameterSetName='NewGroupParent')]
        [Guid]$Parent,

        [Parameter(Mandatory=$true, ParameterSetName='NewGroupTrigger')]
        [Parameter(Mandatory=$true, ParameterSetName='NewGroupParent')]
        [switch]$IsGroup,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        $msg_action = " create"
        if (-not $script:objConfiguration) { Throw('No in memory configuration available') }
        if ($PSCmdlet.ParameterSetName.EndsWith('Trigger')) {
            if ($PSCmdlet.ParameterSetName.Contains('Normal')) {
                $ret = $script:objConfiguration.AddNodeToTrigger($Trigger, $Name)
            } elseif ($PSCmdlet.ParameterSetName.Contains('Group')) {
                $ret = $script:objConfiguration.AddNodeGroupToTrigger($Trigger, $Name)
            }
        } elseif ($PSCmdlet.ParameterSetName.EndsWith('Parent')) {
            if ($PSCmdlet.ParameterSetName.Contains('Normal')) {
                $ret = $script:objConfiguration.AddNodeToParent($Parent, $Name)
            } elseif ($PSCmdlet.ParameterSetName.Contains('Reusable')) {
                $msg_action = " link"
                $ret = $script:objConfiguration.AddReusableNode($Parent, $NodeID)
            } elseif ($PSCmdlet.ParameterSetName.Contains('Group')) {
                $ret = $script:objConfiguration.AddNodeGroupToParent($Parent, $Name)
            }
        }
    } catch {
        $ret = $false
    }
    $msg = if ($ret) { "Successfully" } else { "Failed to" }
    $msg += $msg_action
    $msg += if ($ret) { $(if ($msg_action -eq " link") { "e" } else { "" }) + "d " } else { " " }
    $msg += if ($PSCmdlet.ParameterSetName.Contains("Group")) { "node group" }
    $msg += if ($PSCmdlet.ParameterSetName.Contains("Normal")) { "node" }
    $msg += " $Name"
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

<##########################################################################################
    Aim:        To add actions or conditions to the given parent
    Notes:      The available trigger points, action types and condition typese can be
                found in the AppSense Environment Manager Configuration API.pdf document
    Returns:    The GUID for the created node
                Boolean False on failure
##########################################################################################>
function Add-ConfigurationActionOrCondition() {
    # .ExternalHelp AppSenseDesktopNowEMConfiguration.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName="NormalActionNew")]
        [string]$ActionType,

        [Parameter(Mandatory=$true, ParameterSetName="NormalConditionNew")]
        [string]$ConditionType,

        [Parameter(Mandatory=$true, ParameterSetName="NormalActionNew")]
        [Parameter(Mandatory=$true, ParameterSetName="NormalConditionNew")]
        $Parent,

        [Parameter(Mandatory=$false, ParameterSetName="NormalActionNew")]
        [Parameter(Mandatory=$false, ParameterSetName="NormalConditionNew")]
        [string]$Name,

        [Parameter(Mandatory=$false, ParameterSetName="NormalActionNew")]
        [Parameter(Mandatory=$false, ParameterSetName="NormalConditionNew")]
        $Arguments,

        [Parameter(Mandatory=$false)]
        [System.Collections.Hashtable]$Property,

        [Parameter(Mandatory=$false)]
        [System.Collections.Hashtable]$Method,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        if (-not $script:objConfiguration) { Throw('No in memory configuration available') }
        if ($Arguments) {
            $origArguments = if ($Arguments.GetType().FullName -eq "System.Object[]") { $Arguments.Clone() } else { $Arguments }
        }
        if ($PSCmdlet.ParameterSetName.EndsWith("New")) {
            if ($PSCmdlet.ParameterSetName -eq "NormalActionNew") {
                $aorc = New-Object EMConfigAPI.Actions.$ActionType -ArgumentList $Arguments
            } else {
                #--  these ones need some info from AD --#
                if ($ConditionType -eq 'UserGroupMembership' -or $ConditionType -eq 'UserPrimaryGroup') {
                    $d = ([adsisearcher]"samAccountName=$($Arguments[1])").FindOne()
                    if (-not $d) { Throw 'User group not found' }
                    $Arguments[3] = (New-Object System.Security.Principal.NTAccount(([adsi]'').Name, $Arguments[1])).Translate([System.Security.Principal.SecurityIdentifier])
                    $Arguments[1] = $d.Properties.distinguishedname
                }
                $aorc = New-Object EMConfigAPI.Conditions.$ConditionType -ArgumentList $Arguments
            }
            if ($aorc) {
                if ($Property) { foreach ($key in $Property.Keys) { $aorc.$key = $Property.Item($key) } }
                if ($Method) { foreach ($key in $Method.Keys) { $aorc.GetType().GetMethod($key).Invoke($aorc, $Method.Item($key)) } }
                if ($Name) { $aorc.Name = $Name }
                $res = [Guid]::Empty
                if ([Guid]::TryParse($Parent, [ref]$res)) {
                    $ret = $script:objConfiguration.AddActionOrCondition($res, $aorc)
                }
                # } else {
                #     $ret = $script:objConfiguration.AddEnvironmentActionOrCondition($Parent, $aorc)
                # }
            }
        }
    } catch {
        $ret = $false
    }
    $msg = if ($ret) { "Successfully" } else { "Failed to" }
    $msg += " create"
    $msg += if ($ret) { "d " } else { " " }
    $msg += if ($PSCmdlet.ParameterSetName.Contains("Reusable")) { "reusable " }
    $msg += if ($ActionType) { "action $ActionType" } else { "condition $ConditionType" }
    $msg += if ($origArguments) { " with arguments $origArguments" }
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

<##########################################################################################
    Aim:        To create either a Reusable Node or Reusable Condition and add it to the
                library for later use.
    Notes:      This function does not add actions or conditions to the item.  These must
                be added using Add-ConfigurationActionOrCondition
    Returns:    The GUID for the created library item
                Boolean False on failure
##########################################################################################>
function New-ConfigurationLibraryItem() {
    # .ExternalHelp AppSenseDesktopNowEMConfiguration.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true, ParameterSetName='RN')]
        [switch]$IsReusableNode,

        [Parameter(Mandatory=$true, ParameterSetName='RC')]
        [switch]$IsReusableCondition,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
       $ret = $false
        if ($PSCmdlet.ParameterSetName -eq "RC") {
            $ret = $script:objConfiguration.InsertReusableConditionNode($Name)
        } elseif ($PSCmdlet.ParameterSetName -eq "RN") {
            $ret = $script:objConfiguration.InsertReusableNode($Name)
        } else {
            Throw('Unrecognised ParameterSet')
        }
    } catch {
        $ret = $false
    }
    $msg = if ($ret) { "Successfully" } else { "Failed to" }
    $msg += " create"
    $msg += if ($ret) { "d " } else { " " }
    $msg += "the reusable "
    $msg += if ($PSCmdlet.ParameterSetName -eq "RN") { "node" } else { "condition" }
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

<##########################################################################################
    Aim:        To link and existing library item to the gven parent ot trigger point.
    Returns:    The GUID for the linked item
                Boolean False on failure
##########################################################################################>
function Use-ConfigurationLibraryItem() {
    # .ExternalHelp AppSenseDesktopNowEMConfiguration.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName="ReusableNodeParent")]
        [Parameter(Mandatory=$true, ParameterSetName="ReusableNodeTrigger")]
        [System.Guid]$ReusableNode,

        [Parameter(Mandatory=$true, ParameterSetName="ReusableCondition")]
        [System.Guid]$ReusableCondition,

        [Parameter(Mandatory=$true, ParameterSetName="ReusableNodeParent")]
        [Parameter(Mandatory=$true, ParameterSetName="ReusableCondition")]
        [Guid]$Parent,

        [Parameter(Mandatory=$true, ParameterSetName="ReusableNodeTrigger")]
        [EMConfigAPI.TriggerType]$Trigger,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
       $ret = $false
        if ($PSCmdlet.ParameterSetName -eq "ReusableNodeParent") {
            $ret = $script:objConfiguration.AddReusableNode($Parent, $ReusableNode)
        } elseif ($PSCmdlet.ParameterSetName -eq "ReusableCondition") {
            $ret = $script:objConfiguration.AddReusableCondition($Parent, $ReusableCondition)
        } elseif ($PSCmdlet.ParameterSetName -eq "ReusableNodeTrigger") {
            $ret = $script:objConfiguration.AddReusableNodeToTrigger($Trigger, $ReusableNode)
        }
    } catch {
        $ret = $false
    }
    $msg = if ($ret) { "Successfully" } else { "Failed to" }
    $msg += " link"
    $msg += if ($ret) { "ed " } else { " " }
    $msg += "the reusable "
    $msg += if ($PSCmdlet.ParameterSetName.Contains("ReusableNode")) { "node" } else { "condition" }
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

<##########################################################################################
    Aim:        To set the configuration as per the Configuration Settings tab in the
                Advanced Settings screen.
    Returns:    Boolean - True on success and False on failure
##########################################################################################>
function Set-ConfigurationSetting() {
    # .ExternalHelp AppSenseDesktopNowEMConfiguration.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [EMConfigAPI.ConfigChangeType]$ApplyMidSessionConfigChange = $null,

        [Parameter(Mandatory=$false)]
        [switch]$EnableExtraNetworkNotifications,

        [Parameter(Mandatory=$false)]
        [switch]$EnableLogonSubtriggers,

        [Parameter(Mandatory=$false)]
        [switch]$ResumeInterruptedFolderCopy,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        if (-not $script:objConfiguration) { Throw('No in memory configuration available') }

        $msg = "Settings - Extra notifications: $EnableExtraNetworkNotifications"
        $msg += " Logon subtriggers: $EnableLogonSubtriggers"
        $msg += " Mid-session config changes: $ApplyMidSessionConfigChange"
        $msg += " Resume interrupted folder copy actions: $ResumeInterruptedFolderCopy"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent

        if ($EnableExtraNetworkNotifications) { $script:objConfiguration.EnableExtraNetworkNotifications() } else { $script:objConfiguration.DisableExtraNetworkNotifications() }
        if ($EnableLogonSubtriggers) { $script:objConfiguration.EnableLogonSubtriggers() } else { $script:objConfiguration.DisableLogonSubtriggers() }
        if ($ApplyMidSessionConfigChange -ne $null) { $script:objConfiguration.SetMidSessionConfigChange($ApplyMidSessionConfigChange) }
        if ($ResumeInterruptedFolderCopy) { $script:objConfiguration.Configuration.CancelCopyActionsEnabled = $ResumeInterruptedFolderCopy }

        $ret = $true
    } catch {
        $ret = $false
    }
    $msg = if ($ret) { "Successfully" } else { "Failed to" }
    $msg += " update"
    $msg += if ($ret) { "d " } else { " " }
    $msg += "configuration settings"
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

<##########################################################################################
    Aim:        To add Custom Settings as per the Custom Settings tab in the  Advanced
                Settings screen.
    Notes:      Not passing a value for $Value will cause the settings default value to
                be used
    Returns:    Boolean - True on success and False on failure
##########################################################################################>
function Set-ConfigurationCustomSetting() {
    # .ExternalHelp AppSenseDesktopNowEMConfiguration.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$false)]
        [string[]]$Value,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        if (-not $script:objConfiguration) { Throw('No in memory configuration available') }
        $useDefault = if ($Value) { $false } else { $true }
        if ($useDefault) { $Value = @() }
        $script:objConfiguration.CustomSettingAdd($Name, $useDefault, $Value)
        $ret = $true
    } catch {
        $ret = $false
    }
    $msg = if ($ret) { "Successfully" } else { "Failed to" }
    $msg += " set $Name to "
    $msg += if ($Value) { $Value } else { "default value" }
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

<##########################################################################################
    Aim:        To configure local auditing settings for the configuration.
    Notes:      There is no validation on the event IDs passed in.
                Supplying LocalLogFileFormat or LocalLogFilePath will automatically enable
                sending events to the local log file.
    Returns:    Boolean - True on success and False on failure
##########################################################################################>
function Set-ConfigurationAuditing() {
    # .ExternalHelp AppSenseDesktopNowEMConfiguration.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [switch]$SendToApplicationEventLog,

        [Parameter(Mandatory=$false)]
        [switch]$SendToAppSenseEventLog,

        [Parameter(Mandatory=$false)]
        [switch]$SendToLocalLogFile,

        [Parameter(Mandatory=$false)]
        [switch]$UseAnonymousEvents,

        [Parameter(Mandatory=$false)]
        [EMConfigAPI.LocalAuditLogFormat]$LocalLogFileFormat,

        [Parameter(Mandatory=$false)]
        [AllowEmptyString()]
        [string]$LocalLogFilePath = "",

        [Parameter(Mandatory=$true)]
        [int[]]$Events,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        if (-not $script:objConfiguration) { Throw('No in memory configuration available') }
        $UseLocalLogFile = if ($SendToLocalLogFile -or $LocalLogFilePath -or $LocalLogFileFormat) { $true } else { $false }
        $script:objConfiguration.AuditingGeneralControl($SendToApplicationEventLog, $SendToAppSenseEventLog, $UseAnonymousEvents, $UseLocalLogFile)
        if ($LocalLogFilePath -or $LocalLogFileFormat) { $script:objConfiguration.AuditingSetLocalLog($LocalLogFileFormat, $LocalLogFilePath) }
        $script:objConfiguration.AuditingRaiseEventsLocally($Events)
        $ret = $true
    } catch {
        $ret = $false
    }
    $msg = if ($ret) { "Successfully applied" } else { "Failed to apply" }
    $msg += " local auditing settings"
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

<##########################################################################################
    Aim:        To add a user to the RunAs user library for the configuration.
    Notes:      There is no validation on the credentials at all.
    Returns:    Boolean - True on success and False on failure
##########################################################################################>
function New-ConfigurationRunAsUser() {
    # .ExternalHelp AppSenseDesktopNowEMConfiguration.psm1-help.xml
    [CmdletBinding(DefaultParameterSetName='Plain')]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$FriendlyName,

        [Parameter(Mandatory=$true, ParameterSetName='Plain')]
        [string]$Username,

        [Parameter(Mandatory=$false, ParameterSetName='Plain')]
        [string]$Password,

        [Parameter(Mandatory=$true, ParameterSetName='Credentials')]
        [PSCredential]$Credentials,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        if (-not $script:objConfiguration) { Throw('No in memory configuration available') }
        if ($PSCmdlet.ParameterSetName -eq 'Credentials') {
            $Username = $Credentials.Username
            $Password = Get-UserCredentialsPassword -Credentials $Credentials
        }
        $script:objConfiguration.InsertRunAsUserLibrary($FriendlyName, $Username, $Password)
        $ret = $true
    } catch {
        $ret = $false
    }
    $msg = if ($ret) { "Successfully" } else { "Failed to" }
    $msg += " store"
    $msg += if ($ret) { "d " } else { " " }
    $msg += "$Username into the RunAs user library"
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

<##########################################################################################
    Aim:        To add an item to the Personalization Server list.
    Returns:    Boolean - True on success and False on failure
##########################################################################################>
function New-ConfigurationPersonalizationServer() {
    # .ExternalHelp AppSenseDesktopNowEMConfiguration.psm1-help.xml
    [CmdletBinding(DefaultParameterSetName='Plain')]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$FriendlyName,

        [Parameter(Mandatory=$true)]
        [string]$Server,

        [Parameter(Mandatory=$false)]
        [int]$Port = 0,

        [Parameter(Mandatory=$false)]
        [switch]$UseHTTPS,

        [Parameter(Mandatory=$false, ParameterSetName='VirtualHost')]
        [int]$Retries = 0,

        [Parameter(Mandatory=$false, ParameterSetName='VirtualHost')]
        [int]$RetryDelay = 0,

        [Parameter(Mandatory=$false, ParameterSetName='VirtualHost')]
        [switch]$IsVirtualHost,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        if (-not $script:objConfiguration) { Throw('No in memory configuration available') }
        $script:objConfiguration.AddPersonalizationServer($Server, $FriendlyName, $UseHTTPS, $Port, $IsVirtualHost)
        $sil = $script:objConfiguration.Configuration.ServerInfoList
        if ($sil) {
            $ret = $sil | Where { $_.FriendlyName -eq $FriendlyName -and $_.Url.Contains($Server) }
            if ($ret) {
                if ($PSCmdlet.ParameterSetName -eq 'VirtualHost') {
                    foreach ($s in $ret) {
                        $s.Retries = $Retries
                        $s.Timeout = $RetryDelay
                    }
                }
                $ret = $true
            } else {
                $ret = $false
            }
        }
    } catch {
        $ret = $false
    }
    $msg = if ($ret) { "Successfully" } else { "Failed to" }
    $msg += " add"
    $msg += if ($ret) { "ed " } else { " " }
    $msg += "$Server using port $Port"
    $msg += if ($UseHTTPS) { " using HTTPS" }
    $msg += if ($IsVirtualHost) { " as a virtual host" }
    $msg += " into the Personalization Server list"
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

<##########################################################################################
    Aim:        To add an If condition to the configuration.
    Returns:    Hashtable - ElseGuid - the guid to use when adding actions/conditions to
                                       the false portion of the If expression
                            IfGuid - the guid to use when adding actions/conditions to the
                                     true portion of the If expression
                            ConditionGuid - the guid to use for adding conditions to be
                                            evaluated as part of the If expression
                Boolean - False on failure
##########################################################################################>
function New-ConfigurationIfElseExpression() {
    # .ExternalHelp AppSenseDesktopNowEMConfiguration.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [Guid]$Parent,

        [Parameter(Mandatory=$true)]
        [string]$Description,

        [Parameter(Mandatory=$false)]
        [string]$GroupDescription,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        if (-not $script:objConfiguration) { Throw('No in memory configuration available') }
        $ret = $script:objConfiguration.AddIfElseExpression($Parent, "", $GroupDescription)
        if ($ret) {
            $ret = @{'ElseGuid'=$ret[2]; 'IfExpressionGuid'=$ret[1]; 'IfGroupGuid'=$ret[0]}
            $objMap = Get-ObjectMap
            if ($objMap.ContainsKey($ret['IfExpressionGuid'])) {
                $uemDescription = [UEM.Description]::ManufactureInstance()
                $uemDescription.Text = $Description
                $objMap[$ret['IfExpressionGuid']].AomObject.Description = $uemDescription
            }
        }
    } catch {
        $ret = $false
    }
    $msg = if ($ret) { "Successfully" } else { "Failed to" }
    $msg += " create"
    $msg += if ($ret) { "d " } else { " " }
    $msg += "IfElse expression"
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

<#################################################################################
    Aim:        To add an ElseIf expression to the given IfElse expression
    Returns:    Boolean - False on failure
                Guid - the link ID of the ElseIf expression
#################################################################################>
function New-ConfigurationElseIfExpression() {
    # .ExternalHelp AppSenseDesktopNowEMConfiguration.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [Guid]$IfElseGroupID,

        [Parameter(Mandatory=$true)]
        [Guid]$Parent,

        [Parameter(Mandatory=$true)]
        [string]$Description,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        if (-not $script:objConfiguration) { Throw('No in memory configuration available') }
        $ret = $script:objConfiguration.AddElseIfExpression($IfElseGroupID, $Parent, "")
        $objMap = Get-ObjectMap
        if ($objMap.ContainsKey($ret)) {
            $uemDescription = [UEM.Description]::ManufactureInstance()
            $uemDescription.Text = $Description
            $objMap[$ret].AomObject.Description = $uemDescription
        }
    } catch {
        $ret = $false
    }
    $msg = if ($ret) { "Successfully" } else { "Failed to" }
    $msg += " create"
    $msg += if ($ret) { "d " } else { " " }
    $msg += "ElseIf expression"
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

<#################################################################################
    Aim:        To add a reusable node to the given node group
    Notes:      There appears to be no native method to handle this so I have
                modified the configuration directly.
    Returns:    Boolean - True on success and False on failure
#################################################################################>
function Add-ConfigurationNodeGroupMember()  {
    # .ExternalHelp AppSenseDesktopNowEMConfiguration.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [Guid]$NodeGroupID,

        [Parameter(Mandatory=$false)]
        [guid[]]$Members,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        $objMap = Get-ObjectMap
        if ($objMap.ContainsKey($NodeGroupID)) {
            foreach ($m in $Members) {
                $runnodes = [UEM.RunNodeReference]::ManufactureInstance()
                $runnodes.ResuableNode = $m
                $objMap[$NodeGroupID].AomObject.RunNodes.Add($runnodes)
            }
        }
        $ret = $true
    } catch {
        $ret = $false
    }
    $msg = if ($ret) { "Successfully" } else { "Failed to" }
    $msg += " add"
    $msg += if ($ret) { "ed " } else { " " }
    $msg += if ($ret) { "$($Members.Count) " } else { "" }
    $msg += "members to node group"
    $msg += if ($objMap[$NodeGroupID].AomObject.Name) { $objMap[$NodeGroupID].AomObject.Name } else { "" }
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

<#################################################################################
    Aim:        To import the given template to the given parent or trigger point
    Returns:    Boolean - False on failure
                Guid - the GUID of the top most imported node.
#################################################################################>
function Import-ConfigurationTemplate() {
    # .ExternalHelp AppSenseDesktopNowEMConfiguration.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Template,

        [Parameter(Mandatory=$true, ParameterSetName='ByParent')]
        [Guid]$Parent,

        [Parameter(Mandatory=$true, ParameterSetName='ByTrigger')]
        [EMConfigAPI.TriggerType]$Trigger,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        if (-not (Test-Path $Template)) { Throw("$Template not found.") }
        if ($PSCmdlet.ParameterSetName -eq 'ByTrigger') {
            $ret = $script:objConfiguration.ImportPolicyTemplateToTrigger($Trigger, $Template)
        } else {
            $ret = $script:objConfiguration.ImportPolicyTemplateToNode($Parent, $Template)
        }
    } catch {
        $ret = $false
    }
    $msg = if ($ret) { "Successfully" } else { "Failed to" }
    $msg += " import"
    $msg += if ($ret) { "ed " } else { " " }
    $msg += "$Template to the given parent"
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

<#################################################################################
    Aim:        To create a new EM configuration object
    Notes:      Not exported as this is providing access to the private variable
                used by the dll.
    Returns:    The object map used by the configuration instance.
#################################################################################>
function Get-ObjectMap() {
    $fldObjectMap = $script:objConfiguration.GetType().GetField("_objectMap", [Reflection.BindingFlags]::NonPublic -bor [Reflection.BindingFlags]::Instance)
    $ret = $fldObjectMap.GetValue($script:objConfiguration)
    return $ret
}

Export-ModuleMember -Function *-Configuration*, Set-LogPath