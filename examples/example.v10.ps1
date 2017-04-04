<##############################################################################################################################
    This is an example script that demonstrates using the AppSenseDesktopNowModule in order to install and configure
    both the AMC and EMPS.  In the process of doing this SQL Express is installed.

    If using Server 2012 R2 please ensure that the SXS folder is available to point to from the original source media.

    This script demonstrates using PowerShell sessions to install all components on one server and configure them.  It also
    shows the ability to import the individual modules (Binary, BinaryAncillary, Configuration etc) in order to get the job
    done.  This shouldn't distract from the fact that you can import the entire module (AppSenseDesktopNow) if need be.

    The assumption is made that the files required are already in the locations specified - no files are downloaded in this
    script.

    The BinaryAncillary module is used in order to install SQL Server Express and optionally SSMS.

    The examples in this script also show passing additional arguments to the Windows Installer.
##############################################################################################################################>

# $ProgressPreference = "SilentlyContinue"
$configCreds = New-Object System.Management.Automation.PSCredential("$env:UserDomain\svcAppSenseConfig", (ConvertTo-SecureString -AsPlainText "Welcome21" -Force))
$serviceCreds = New-Object System.Management.Automation.PSCredential("$env:UserDomain\svcAppSenseComms", (ConvertTo-SecureString -AsPlainText "Welcome21" -Force))
$dbInstance = "MySQLInstance"
$dbServer = "$([System.Net.Dns]::GetHostName())\$dbInstance"
$srcSxs = "D:\sources\sxs"
$srcPath = "C:\DesktopNowInstall"
$srcLogPath = "C:\Temp\AppSenseDesktopNow_LogFile.txt"
$modPath = Split-Path -Path (Get-Location)

#-- Do the binary installs --#
Import-Module "$modPath\Binary\AppSenseDesktopNowInstaller" -Force
$ret = Set-AppSenseDesktopNowLogPath -Path $srcLogPath -TrackTime -Verbose
if (-not $ret) { return $ret }
if (Set-AppSenseDesktopNowBasePath $srcPath -TrackTime -Verbose) {
    $ret = Add-AppSenseDesktopNowComponent -Component ManagementCenter -SetupParams "PATCH=$srcPath\Software\Products\ManagementServer64.msp" -TrackTime -Verbose
    if ($ret) { $ret = Add-AppSenseDesktopNowConsole -Console ManagementCenter -SetupParams "MANAGEMENTSERVERURL=`"http://$([System.Net.Dns]::GetHostName())`"" -TrackTime -Verbose }
    if ($ret) { $ret = Add-AppSenseDesktopNowComponent -Component PersonalizationServer -SxSPath $sxsPath -SetupParams "PATCH=$srcPath\Software\Products\PersonalizationServer64.msp" -TrackTime -Verbose }
    if ($ret) { $ret = Add-AppSenseDesktopNowConsole -Console EnvironmentManagerPolicyAndPersonalization -TrackTime -Verbose }
}
if (-not $ret) { return $ret }

#-- Do the SQL Express Installation --#
try {
    $sqlSession = New-PSSession -ComputerName $([System.Net.Dns]::GetHostName()) -Name "AppSense DesktopNow SQL Express Installation & Configuration" -ErrorAction Stop
} catch {
    Write $_
    exit
}
$ret = Invoke-Command -Session $sqlSession -ArgumentList $srcSxs -ScriptBlock {
    param($sxsPath)

    $ProgressPreference = $Using:ProgressPreference
    Import-Module "$($Using:modPath)\BinaryAncillary\AppSenseDesktopNowBinaryAncillary" -Force
    $ret = Set-AppSenseDesktopNowLogPath -Path $Using:srcLogPath -TrackTime -Verbose
    if ($ret) { $ret = Add-AppSenseDesktopNowAncillary -UseShell -AncillaryPath "$($Using:srcPath)\Software\Prerequisites\SQLEXPR_x64_ENU.exe" -ArgList @("/ConfigurationFile=`"$($Using:srcPath)\Software\Prerequisites\sqlexpress.ini`"", "/InstanceName=`"$($Using:dbInstance)`"", '/SAPWD=Welcome21','/NPENABLED=1', '/TCPENABLED=1', '/HIDECONSOLE', '/Q') -TrackTime -Verbose }
    #-- installing SSMS is completely optional --#
    Add-WindowsFeature "Net-Framework-Core" -Source $sxsPath
    if ($ret) { $ret = Add-AppSenseDesktopNowAncillary -AncillaryPath "C:\Installers\SQLManagementStudio_x64_ENU.exe" -ArgList @('/Action=install', "/InstanceName=`"$($Using:dbInstance)`"", 'Features=Tools', '/IACCEPTSQLSERVERLICENSETERMS', '/Q') -TrackTime -Verbose }
    return $ret
}
Remove-PSSession -Session $sqlSession
if (-not $ret) { return $ret }

#-- Automate the SCU for the AMC --#
try {
    $amcSession = New-PSSession -ComputerName $([System.Net.Dns]::GetHostName()) -Name "AMC SCU Automation" -ErrorAction Stop
} catch {
    Write $_
    exit
}
$ret = Invoke-Command -Session $amcSession -ArgumentList "AMS-MODULE-DEFAULT" -ScriptBlock {
    param($dbName)
    $ProgressPreference = $Using:ProgressPreference
    Import-Module "$($Using:modPath)\Configuration\AppSenseDesktopNowConfiguration" -Force
    $ret = Set-AppSenseDesktopNowLogPath -Path $Using:srcLogPath -TrackTime -Verbose
    if ($ret) { $ret = Initialize-AppSenseDesktopNowInstance -ProductName ManagementCenter -DatabaseConnection "AMC DB Connection" -DatabaseServer $Using:dbServer -DatabaseName $dbName -ConfigurationCredentials $Using:configCreds -ServiceCredentials $Using:serviceCreds -CreateConfigurer -TrackTime -Verbose }
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
$ret = Invoke-Command -Session $empsSession -ArgumentList "EMPS-MODULE-DEFAULT" -ScriptBlock {
    param($dbName)
    $ProgressPreference = $Using:ProgressPreference
    Import-Module "$($Using:modPath)\Configuration\AppSenseDesktopNowConfiguration" -Force
    $ret = Set-AppSenseDesktopNowLogPath -Path $Using:srcLogPath -TrackTime -Verbose
    if ($ret) { $ret = Initialize-AppSenseDesktopNowInstance -ProductName PersonalizationAndPersOps -DatabaseConnection "EMPS DB Connection" -DatabaseServer $Using:dbServer -DatabaseName $dbName -ConfigurationCredentials $Using:configCreds -ServiceCredentials $Using:serviceCreds -CreateConfigurer -TrackTime -Verbose }
    return $ret
}
Remove-PSSession -Session $empsSession
if (-not $ret) { return $ret }

#-- Automate AMC Web Services API --#
try {
    $awsSession = New-PSSession -ComputerName $([System.Net.Dns]::GetHostName()) -Name "AMC Web Services API Automation" -ErrorAction Stop
} catch {
    Write $_
    exit
}
$ret = Invoke-Command -Session $awsSession -ScriptBlock {
    Import-Module "$($Using:modPath)\BAU\AMC\AppSenseDesktopNowAMC" -Force
    Import-Module "$($Using:modPath)\Configuration\AppSenseDesktopNowConfiguration" -Force
    $amcInstance = Get-AppSenseDesktopNowInstanceDetails -ProductName ManagementCenter
    if ($amcInstance) {
        $ret = Set-AppSenseManagementServerLogPath -Path $Using:srcLogPath -TrackTime -Verbose
        if ($ret) { $ret = Get-AppSenseDesktopNowInstanceProperties -ProductName ManagementCenter -TrackTime -Verbose }
        if ($ret) { $ret = Connect-AppSenseManagementServer -Server $([System.Net.Dns]::GetHostName()) -Port $amcInstance.LocalPort -UseCurrentUser -TrackTime -Verbose }
        if ($ret) { $ret = Set-AppSenseManagementServerSecurityConfiguredUser -Username "$env:UserDomain\Domain Admins" -SecurityRoles "Server Administrator" -TrackTime -Verbose }
        if ($ret) {
            $agents = Get-ChildItem -Path "$($Using:srcPath)\Software\Products\*Agent*.msi"
            foreach ($a in $agents) { $ret = Import-AppSenseManagementServerPackage -PackagePath "$($a.FullName)" -PrerequisitePath "$($Using:srcPath)\Software\Prerequisites" -ShowProgress -TrackTime -Verbose }
            $patches = Get-ChildItem -Path "$($Using:srcPath)\Software\Products\*Agent*.msp"
            foreach ($p in $patches) { $ret = Import-AppSenseManagementServerPackage -PackagePath "$($p.FullName)" -ShowProgress -TrackTime -Verbose }
        }
    }
}
Remove-PSSession -Session $awsSession
if (-not $ret) { return $ret }