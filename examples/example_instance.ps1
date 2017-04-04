<##############################################################################################################################
    This is an example script that demonstrates using the AppSenseDesktopNowModule in order to install and configure
    both the AMC and EMPS.  In the process of doing this SQL Express is installed.

    If using Server 2012 R2 please ensure that the SXS folder is available to point to from the original source media.

    This script demonstrates using PowerShell sessions to install all components on one server and configure them.  It also
    shows the ability to import the individual modules (Binary, BinaryAncillary, Configuration etc) in order to get the job
    done.  This shouldn't distract from the fact that you can import the entire module (AppSenseDesktopNow) if need be.
    This script also uses a copy action to put the agents into the correct location for them to be uploaded into the AMC.

    The assumption is made that the files required are already in the locations specified - no files are downloaded in this
    script.

    The BinaryAncillary module is used in order to install SQL Server Express and optionally SSMS.

    The examples in this script also show passing additional arguments to the Windows Installer.
##############################################################################################################################>

$ProgressPreference = "SilentlyContinue"
$configCreds = New-Object System.Management.Automation.PSCredential("$env:UserDomain\svcAppSenseConfig", (ConvertTo-SecureString -AsPlainText "Welcome21" -Force))
$serviceCreds = New-Object System.Management.Automation.PSCredential("$env:UserDomain\svcAppSenseComms", (ConvertTo-SecureString -AsPlainText "Welcome21" -Force))
$compInstance = "Example"
$compPort = 81
$dbInstance = "MySQLInstance"
$dbServer = "$([System.Net.Dns]::GetHostName())\$dbInstance"
$srcPath = "C:\DesktopNowInstall"
$srcLogPath = "C:\Temp\AppSenseDesktopNow_LogFile.txt"
$modPath = Split-Path -Path (Get-Location)

#-- Do the binary installs --#
try {
    $binarySession = New-PSSession -ComputerName $([System.Net.Dns]::GetHostName()) -Name "AppSense DesktopNow Binary Installation" -ErrorAction Stop
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
        $ret = Add-AppSenseDesktopNowComponent -Component ManagementCenter -InstanceName $Using:compInstance -SetupParams "PATCH=$($Using:srcPath)\Software\Products\ManagementServer64.msp" -TrackTime -Verbose
        if ($ret) { $ret = Add-AppSenseDesktopNowConsole -Console ManagementCenter -SetupParams "PATCH=$($Using:srcPath)\Software\Products\ManagementConsole64.msp", "MANAGEMENTSERVERURL=`"http://$([System.Net.Dns]::GetHostName())`:$Using:compPort`"" -TrackTime -Verbose }
        if ($ret) { $ret = Add-AppSenseDesktopNowComponent -Component PersonalizationServer -InstanceName $Using:compInstance -SxSPath $sxsPath -SetupParams "PATCH=$($Using:srcPath)\Software\Products\PersonalizationServer64.msp" -TrackTime -Verbose }
        if ($ret) { $ret = Add-AppSenseDesktopNowConsole -Console EnvironmentManagerPolicyAndPersonalization -SetupParams "PATCH=$($Using:srcPath)\Software\Products\EnvironmentManagerConsole64.msp" -TrackTime -Verbose }
        return $ret
    }
}
Remove-PSSession -Session $binarySession
if (-not $ret) { return $ret }

#-- Do the SQL Express Installation (doing after the binaries as SSMS needs .NET 3.5 which will be installed with EMPS) --#
try {
    $sqlSession = New-PSSession -ComputerName $([System.Net.Dns]::GetHostName()) -Name "AppSense DesktopNow SQL Express Installation & Configuration" -ErrorAction Stop
} catch {
    Write $_
    exit
}
$ret = Invoke-Command -Session $sqlSession -ScriptBlock {
    $ProgressPreference = $Using:ProgressPreference
    Import-Module "$($Using:modPath)\BinaryAncillary\AppSenseDesktopNowBinaryAncillary" -Force
    $ret = Set-AppSenseDesktopNowLogPath -Path $Using:srcLogPath -TrackTime -Verbose
    if ($ret) { $ret = Add-AppSenseDesktopNowAncillary -AncillaryPath "$($Using:srcPath)\Software\Prerequisites\SQLEXPR_x86_ENU.exe" -ArgList @("/ConfigurationFile=`"$($Using:srcPath)\Software\Prerequisites\sqlexpress.ini`"", "/InstanceName=`"$($Using:dbInstance)`"", '/SAPWD=Welcome21','/NPENABLED=1', '/TCPENABLED=1', '/HIDECONSOLE') -TrackTime -Verbose }
    #-- installing SSMS is completely optional --#
    if ($ret) { $ret = Add-AppSenseDesktopNowAncillary -AncillaryPath "C:\Installers\SQLManagementStudio_x86_ENU.exe" -ArgList @('/Action=install', "/InstanceName=`"$($Using:dbInstance)`"", 'Features=Tools', '/IACCEPTSQLSERVERLICENSETERMS', '/Q') -TrackTime -Verbose }
    return $ret
}
Remove-PSSession -Session $sqlSession
if (-not $ret) { return $ret }

#-- Get the AMC install path so that we can copy the agents there --#
try {
    $amcSession = New-PSSession -ComputerName $([System.Net.Dns]::GetHostName()) -Name "AMC Get Install Path" -ErrorAction Stop
} catch {
    Write $_
    exit
}
$ret = Invoke-Command -Session $amcSession -ScriptBlock {
    $ProgressPreference = $Using:ProgressPreference
    Import-Module "$($Using:modPath)\Configuration\AppSenseDesktopNowConfiguration" -Force
    $ret = Get-AppSenseDesktopNowInstanceInstallPath -ProductName ManagementCenter -InstanceName $Using:compInstance -TrackTime -Verbose
    return $ret
}
Remove-PSSession -Session $amcSession
if (-not $ret) { return $ret }

#-- Automate the SCU for the AMC --#
try {
    $amcSession = New-PSSession -ComputerName $([System.Net.Dns]::GetHostName()) -Name "AMC SCU Automation" -ErrorAction Stop
} catch {
    Write $_
    exit
}
$ret = Invoke-Command -Session $amcSession -ArgumentList "AMS-MODULE-$compInstance", $ret -ScriptBlock {
    param($dbName, $pathInstall)
    $ProgressPreference = $Using:ProgressPreference
    #-- copy agents ready for upload (should really get the path from the instance cmdlets but this should work for a default instance) --#
    $pathAgent = "$pathInstall\Agents"
    New-Item -Path $pathAgent -Type Directory -Force | Out-Null
    Copy-Item "$($Using:srcPath)\Software\Products\*Agent*.ms*" $pathAgent
    #-- start the SCU stuff now --#
    Import-Module "$($Using:modPath)\Configuration\AppSenseDesktopNowConfiguration" -Force
    $ret = Set-AppSenseDesktopNowLogPath -Path $Using:srcLogPath -TrackTime -Verbose
    if ($ret) { $ret = Initialize-AppSenseDesktopNowInstance -ProductName ManagementCenter -InstanceName $Using:compInstance -WebsitePort $Using:compPort -DatabaseServer $Using:dbServer -DatabaseName $dbName -ConfigurationCredentials $Using:configCreds -ServiceCredentials $Using:serviceCreds -CreateWebsite -CreateConfigurer -TrackTime -Verbose }
    return $ret
}
Remove-PSSession -Session $amcSession
if (-not $ret) { return $ret }

#-- Automate the SCU for EMPS --#
try {
    $empsSession = New-PSSession -ComputerName $([System.Net.Dns]::GetHostName()) -Name "EMPS SCU Automation" -ErrorAction Stop
} catch {
    Write $_
    exit
}
$ret = Invoke-Command -Session $empsSession -ArgumentList "EMPS-MODULE-$compInstance" -ScriptBlock {
    param($dbName)
    $ProgressPreference = $Using:ProgressPreference
    Import-Module "$($Using:modPath)\Configuration\AppSenseDesktopNowConfiguration" -Force
    $ret = Set-AppSenseDesktopNowLogPath -Path $Using:srcLogPath -TrackTime -Verbose
    if ($ret) { $ret = Initialize-AppSenseDesktopNowInstance -ProductName PersonalizationAndBrowserInterface -InstanceName $Using:compInstance -WebsitePort $Using:compPort -DatabaseServer $Using:dbServer -DatabaseName $dbName -ConfigurationCredentials $Using:configCreds -ServiceCredentials $Using:serviceCreds -CreateWebsite -CreateConfigurer -TrackTime -Verbose }
    return $ret
}
Remove-PSSession -Session $empsSession
if (-not $ret) { return $ret }