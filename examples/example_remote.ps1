<##############################################################################################################################
    This is an example script that demonstrates using the AppSenseDesktopNowModule in order to install and configure
    both the AMC and EMPS.  In the process of doing this SQL Express is installed.

    If using Server 2012 R2 please ensure that the SXS folder is available to point to from the original source media.

    This script demonstrates using PowerShell sessions to install all components on one server and configure them.  It also
    shows the ability to import the individual modules (Binary, Configuration etc) in order to get the job done.
    This shouldn't distract from the fact that you can import the entire module (AppSenseDesktopNow) if need be.
    This script also uses a copy action to put the agents into the correct location for them to be uploaded into the AMC.

    SQL Express is not installed and neither is SSMS.  The assumption is made that an external SQL server is beig used with
    all the necessary SQL logins created and added to the correct server roles.

    CredSSP is used as the authentication method for the session.  See the following URL for more information:
            https://technet.microsoft.com/en-us/library/hh849872(v=wps.620).aspx

    The examples in this script also show passing additional arguments to the Windows Installer.
##############################################################################################################################>

$ProgressPreference = "SilentlyContinue"
$credsspCreds = New-Object System.Management.Automation.PSCredential("$env:UserDomain\Administrator", (ConvertTo-SecureString -AsPlainText "Welcome21" -Force))
$configCreds = New-Object System.Management.Automation.PSCredential("$env:UserDomain\svcAppSenseConfig", (ConvertTo-SecureString -AsPlainText "Welcome21" -Force))
$serviceCreds = New-Object System.Management.Automation.PSCredential("$env:UserDomain\svcAppSenseComms", (ConvertTo-SecureString -AsPlainText "Welcome21" -Force))
$targetMachine = "desktopnow03"
$dbInstance = "SQLEXPRESS"
$dbServer = "$([System.Net.Dns]::GetHostName())\$dbInstance"
$srcPath = "C:\DesktopNowInstall"
$srcLogPath = "C:\Temp\AppSenseDesktopNow_LogFile.txt"
$modPath = Split-Path -Path (Get-Location)

#-- Do the binary installs --#
try {
    $binarySession = New-PSSession -ComputerName $targetMachine -Name "AppSense DesktopNow Binary Installation" -Authentication Credssp -Credential $credsspCreds -ErrorAction Stop
} catch {
    Write $_
    exit
}
$ret = Invoke-Command -Session $binarySession -ArgumentList "D:\sources\sxs" -ScriptBlock {
    param($sxsPath)
    $ProgressPreference = $Using:ProgressPreference
    Import-Module "$($Using:modPath)\Binary\AppSenseDesktopNowInstaller" -Force
    $ret = Set-AppSenseDesktopNowLogPath -Path $Using:srcLogPath -TrackTime -Verbose
    if (-not $ret) { return $ret }
    if (Set-AppSenseDesktopNowBasePath $Using:srcPath -TrackTime -Verbose) {
        $ret = Add-AppSenseDesktopNowComponent -Component ManagementCentre -SetupParams "PATCH=$($Using:srcPath)\Software\Products\ManagementServer64.msp" -TrackTime -Verbose
        if ($ret) { $ret = Add-AppSenseDesktopNowConsole -Console ManagementCenter -SetupParams "PATCH=$($Using:srcPath)\Software\Products\ManagementConsole64.msp", "MANAGEMENTSERVERURL=`"http://$($Using:targetMachine)`"" -TrackTime -Verbose }
        if ($ret) { $ret = Add-AppSenseDesktopNowComponent -Component PersonalizationServer -SxSPath $sxsPath -SetupParams "PATCH=$($Using:srcPath)\Software\Products\PersonalizationServer64.msp" -TrackTime -Verbose }
        if ($ret) { $ret = Add-AppSenseDesktopNowConsole -Console EnvironmentManagerPolicyAndPersonalization -SetupParams "PATCH=$($Using:srcPath)\Software\Products\EnvironmentManagerConsole64.msp" -TrackTime -Verbose }
        return $ret
    }
}
Remove-PSSession -Session $binarySession
if (-not $ret) { return $ret }

#-- Automate the SCU for the AMC --#
try {
    $amcSession = New-PSSession -ComputerName $targetMachine -Name "AMC SCU Automation" -Authentication Credssp -Credential $credsspCreds -ErrorAction Stop
} catch {
    Write $_
    exit
}
$ret = Invoke-Command -Session $amcSession -ArgumentList "AMS-MODULE-DEFAULT" -ScriptBlock {
    param($dbName)
    $ProgressPreference = $Using:ProgressPreference
    #-- copy agents ready for upload (should really get the path from the instance cmdlets but this should work for a default instance) --#
    $pathAgent = "$env:ProgramFiles\AppSense\Management Center\Server\Bin\Agents"
    New-Item -Path $pathAgent -Type Directory -Force | Out-Null
    Copy-Item "$($Using:srcPath)\Software\Products\*Agent*.ms*" $pathAgent
    #-- start the SCU stuff now --#
    Import-Module "$($Using:modPath)\Configuration\AppSenseDesktopNowConfiguration" -Force
    $ret = Set-AppSenseDesktopNowLogPath -Path $Using:srcLogPath -TrackTime -Verbose
    if ($ret) { $ret = Initialize-AppSenseDesktopNowInstance -ProductName ManagementCenter -DatabaseServer $Using:dbServer -DatabaseName $dbName -ConfigurationCredentials $Using:configCreds -ServiceCredentials $Using:serviceCreds -TrackTime -Verbose }
    return $ret
}
Remove-PSSession -Session $amcSession
if (-not $ret) { return $ret }

#-- Automate the SCU for EMPS --#
try {
    $empsSession = New-PSSession -ComputerName $targetMachine -Name "EMPS SCU Automation" -Authentication Credssp -Credential $credsspCreds -ErrorAction Stop
} catch {
    Write $_
    exit
}
$ret = Invoke-Command -Session $empsSession -ArgumentList "EMPS-MODULE-DEFAULT" -ScriptBlock {
    param($dbName)
    $ProgressPreference = $Using:ProgressPreference
    Import-Module "$($Using:modPath)\Configuration\AppSenseDesktopNowConfiguration" -Force
    $ret = Set-AppSenseDesktopNowLogPath -Path $Using:srcLogPath -TrackTime -Verbose
    if ($ret) { $ret = Initialize-AppSenseDesktopNowInstance -ProductName PersonalizationAndBrowserInterface -DatabaseServer $Using:dbServer -DatabaseName $dbName -ConfigurationCredentials $Using:configCreds -ServiceCredentials $Using:serviceCreds -TrackTime -Verbose }
    return $ret
}
Remove-PSSession -Session $empsSession
if (-not $ret) { return $ret }