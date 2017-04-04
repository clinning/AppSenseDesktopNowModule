<##############################################################################################################################
    This is an example script that demonstrates using the AppSenseDesktopNowModule in order to build a brand new EM
    configuration using the API.

    The resultant configuration is completely nonsensical.  The example is purely here to demonstrate usage of the cmdlets
    that are available.
##############################################################################################################################>

Import-Module ..\BAU\EMConfig\AppSenseDesktopNowEMConfiguration -Force

Set-AppSenseDesktopNowEMLogPath -Path "C:\Temp\emconfig.log" | Out-Null
if (New-AppSenseDesktopNowEMConfiguration -TrackTime -Verbose) {
    $pathConfiguration = "_test.aemp" #where to save the configuration

    #-- set the configuration to apply immediately if downloaded mid-session --#
    Set-AppSenseDesktopNowEMConfigurationSetting -ApplyMidSessionConfigChange Immediately -EnableExtraNetworkNotifications:$false -EnableLogonSubtriggers -ResumeInterruptedFolderCopy:$false -TrackTime -Verbose | Out-Null

    #-- add some custom settings --#
    Set-AppSenseDesktopNowEMConfigurationCustomSetting -Name AddPrinterConnectionRetry -Value 1 -TrackTime -Verbose | Out-Null
    Set-AppSenseDesktopNowEMConfigurationCustomSetting -Name AddPrinterSequential -TrackTime -Verbose | Out-Null
    Set-AppSenseDesktopNowEMConfigurationCustomSetting -Name PrinterErrorCodes -Value 9018, 9012 -TrackTime -Verbose | Out-Null

    #-- do some auditing --#
    Set-AppSenseDesktopNowEMConfigurationAuditing -SendToApplicationEventLog -SendToAppSenseEventLog -UseAnonymousEvents -SendToLocalLogFile -Events @(9302, 9303, 1000) -TrackTime -Verbose | Out-Null

    #-- add an EMPS item to the list --#
    New-AppSenseDesktopNowEMConfigurationPersonalizationServer -Server "localhost" -FriendlyName "Test" -Port 443 -UseHTTPS -TrackTime -Verbose | Out-Null
    New-AppSenseDesktopNowEMConfigurationPersonalizationServer -Server "localhost" -FriendlyName "TestVH" -IsVirtualHost -TrackTime -Verbose | Out-Null
    New-AppSenseDesktopNowEMConfigurationPersonalizationServer -Server "localhost" -FriendlyName "TestVH1" -IsVirtualHost -Retries 3 -RetryDelay 100 -TrackTime -Verbose | Out-Null

    #-- Create some nodes in varying places --#
    $nPreDesktop = New-AppSenseDesktopNowEMConfigurationNode -Name "NodePreDesktop" -Trigger UserPreDesktop -TrackTime -Verbose
    $ngPreSession = New-AppSenseDesktopNowEMConfigurationNode -Name "NodeGroupPreSession" -Trigger UserPreSession -IsGroup -TrackTime -Verbose
    $rn1 = New-AppSenseDesktopNowEMConfigurationLibraryItem -Name "ReusableNode1" -IsReusableNode -TrackTime -Verbose
    $rn2 = New-AppSenseDesktopNowEMConfigurationLibraryItem -Name "ReusableNode2" -IsReusableNode -TrackTime -Verbose
    $nProcessStartedNotepad = New-AppSenseDesktopNowEMConfigurationNode -Name "Notepad" -Trigger UserProcessStarted -TrackTime -Verbose

    #-- Use the reusable node in a couple of places --#
    $rnDesktopCreated = Use-AppSenseDesktopNowEMConfigurationLibraryItem -ReusableNode $rn1 -Trigger UserDesktopCreated -TrackTime -Verbose
    $ngChildReusableDesktopCreated = New-AppSenseDesktopNowEMConfigurationNode -Name "NodeGroupChildReusableDesktopCreated" -Parent $rnDesktopCreated -IsGroup -TrackTime -Verbose
    $nChildReusableDesktopCreated = New-AppSenseDesktopNowEMConfigurationNode -Name "NodeChildReusableDesktopCreated" -Parent $rnDesktopCreated -TrackTime -Verbose
    $rnPreDesktop = Use-AppSenseDesktopNowEMConfigurationLibraryItem -ReusableNode $rn1 -Parent $nPreDesktop -TrackTime -Verbose
    Add-AppSenseDesktopNowEMConfigurationNodeGroupMember -NodeGroupID $ngPreSession -Members $rn1 -TrackTime -Verbose | Out-Null
    Add-AppSenseDesktopNowEMConfigurationNodeGroupMember -NodeGroupID $ngChildReusableDesktopCreated -Members $rn1, $rn2 -TrackTime -Verbose | Out-Null

    #-- Add some conditions and actions to the Notepad Process Started node --#
    $cProcessStartedNotepad = Add-AppSenseDesktopNowEMConfigurationActionOrCondition -Parent $nProcessStartedNotepad -ConditionType "UserProcessName" -Name "Notepad started" -Arguments Equal, "notepad.exe" -TrackTime -Verbose
    $cProcessStartedNotepadIsLaptop = Add-AppSenseDesktopNowEMConfigurationActionOrCondition -Parent $cProcessStartedNotepad -ConditionType "IsLaptop" -TrackTime -Verbose
    $aProcessStartedNotepadIsLaptopMapDrive = Add-AppSenseDesktopNowEMConfigurationActionOrCondition -Parent $cProcessStartedNotepadIsLaptop -ActionType "DriveMap" -Name "Map T Drive" -Arguments "T", "\\fileserver\share", $true -TrackTime -Verbose

    #-- Create a reusable condition and add a condition to it --#
    $rc1 = New-AppSenseDesktopNowEMConfigurationLibraryItem -IsReusableCondition -Name "ReusableCondition1" -TrackTime -Verbose
    $rc1IsAdmin = Add-AppSenseDesktopNowEMConfigurationActionOrCondition -Parent $rc1 -ConditionType "UserIsAdministrator" -Arguments $true -TrackTime -Verbose

    #-- Use the reusable condition in a couple of places --#
    $rcnPreDesktop = Use-AppSenseDesktopNowEMConfigurationLibraryItem -Parent $nPreDesktop -ReusableCondition $rc1 -TrackTime -Verbose
    $rcrn1 = Use-AppSenseDesktopNowEMConfigurationLibraryItem -Parent $rn1 -ReusableCondition $rc1 -TrackTime -Verbose

    #-- Put an action in the reusable node --#
    $arcrn1 = Add-AppSenseDesktopNowEMConfigurationActionOrCondition -Parent $rcrn1 -ActionType "RegistrySetValue" -Arguments "HKEY_CURRENT_USER", "Software\uvjim", "testvalue", "" -Property @{"ValueEXPAND_SZ" = "%UserProfile%\Desktop"} -TrackTime -Verbose
    $aarcrn1 = Add-AppSenseDesktopNowEMConfigurationActionOrCondition -Parent $arcrn1 -ActionType "RegistryDeleteValue" -Arguments "HKEY_CURRENT_USER", "Software\uvjim", "testvalue", System, $false -TrackTime -Verbose

    #-- Put some actions in the PreDesktop node --#
    $arcnPreDesktop1 = Add-AppSenseDesktopNowEMConfigurationActionOrCondition -Parent $rcnPreDesktop -ActionType "CreateFolder" -Arguments "%UserProfile%\Desktop\TestFolder" -TrackTime -Verbose
    $arcnPreDesktop2 = Add-AppSenseDesktopNowEMConfigurationActionOrCondition -Parent $rcnPreDesktop -ActionType "FileRename" -Arguments "FromFile", "ToFile" -TrackTime -Verbose

    #-- Create a RunAs user --#
    New-AppSenseDesktopNowEMConfigurationRunAsUser -FriendlyName "RU1" -Username "test" -Password "test" -TrackTime -Verbose | Out-Null
    New-AppSenseDesktopNowEMConfigurationRunAsUser -FriendlyName "RU2" -Credentials (Get-Credential -UserName "TEST\test" -Message "Creds for RU2") -TrackTime -Verbose | Out-Null

    #-- Use the RunAs user somewhere --#
    $grpName = "GLOBAL_Network Tools"
    $cnPreDesktopUserGroup = Add-AppSenseDesktopNowEMConfigurationActionOrCondition -Parent $nPreDesktop -ConditionType "UserGroupMembership" -Name "User in $grpName" -Arguments Equal, $grpName, $null, $null, $true, $false -TrackTime -Verbose
    $anPreDesktop = Add-AppSenseDesktopNowEMConfigurationActionOrCondition -Parent $cnPreDesktopUserGroup -ActionType "DeleteFile" -Arguments "C:\pathtofile\filetodelete.txt", $true, $null, $null, AsUser, "RU2", $false -TrackTime -Verbose
    $cnPreDesktopCitrixClientSettings = Add-AppSenseDesktopNowEMConfigurationActionOrCondition -Parent $nPreDesktop -ConditionType "CitrixClientSettings" -Method @{'SetClientOS'='Android'; 'SetClientVersion'=@([EMConfigAPI.Conditions.CitrixClientSettings+CitrixClientConditionOperator]::Equal, "1.2.3.4")} -TrackTime -Verbose

    #-- Create an If..Else --#
    $ifnChildReusableDesktopCreated = New-AppSenseDesktopNowEMConfigurationIfElseExpression -Parent $nChildReusableDesktopCreated -GroupDescription "___ Group Description ___" -Description "___ If Description ___" -TrackTime -Verbose
    $ifCondition = Add-AppSenseDesktopNowEMConfigurationActionOrCondition -Parent $ifnChildReusableDesktopCreated.IfGroupGuid -ConditionType "RegistryKeyExists" -Arguments "HKEY_CURRENT_USER", "SOFTWARE\uvjim", Exist, $false -TrackTime -Verbose
    $ifaTrue = Add-AppSenseDesktopNowEMConfigurationActionOrCondition -Parent $ifnChildReusableDesktopCreated.IfExpressionGuid -ActionType "EnvironmentVariableSet" -Arguments "EnVarName1", "EnvVarValue1" -TrackTime -Verbose
    $ifaElse = Add-AppSenseDesktopNowEMConfigurationActionOrCondition -Parent $ifnChildReusableDesktopCreated.ElseGuid -ActionType "EnvironmentSetSessionVariable" -Arguments "SessionVarName", "SessionVarValue" -TrackTime -Verbose
    $elseIf = New-AppSenseDesktopNowEMConfigurationElseIfExpression -IfElseGroupID $ifnChildReusableDesktopCreated.IfGroupGuid -Parent $ifnChildReusableDesktopCreated.IfExpressionGuid -Description "___ ElseIf Description ___" -TrackTime -Verbose
    $elseifCondition = Add-AppSenseDesktopNowEMConfigurationActionOrCondition -Parent $elseIf -ConditionType "RegistryKeyExists" -Arguments "HKEY_CURRENT_USER", "SOFTWARE\uvjim123", Exist, $false -TrackTime -Verbose
    $elseifaTrue = Add-AppSenseDesktopNowEMConfigurationActionOrCondition -Parent $elseIf -ActionType "EnvironmentVariableSet" -Arguments "EnVarName2", "EnvVarValue2" -TrackTime -Verbose

    #-- Import a template into the configuration --'
    Import-AppSenseDesktopNowEMConfigurationTemplate -Template ".\import_test.xml" -Trigger UserDesktopCreated -TrackTime -Verbose | Out-Null
    Import-AppSenseDesktopNowEMConfigurationTemplate -Template ".\import_test.xml" -Parent $rn1 -TrackTime -Verbose | Out-Null

    #-- save the config --#
    Save-AppSenseDesktopNowEMConfiguration -Path $pathConfiguration -TrackTime -Verbose | Out-Null
}