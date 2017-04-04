$jsonConfig = $ConfigReader.PSObject.Copy()
$jsonConfig.Path = $AppSenseDefaults.Installer.DefaultConfig
$BASE_PATH = Convert-Path .

if (-not (Test-IsAdmin -TrackTime)) {
    $modulename = Get-ModuleName -ModulePath $PSCommandPath -TrackTime
    $msg = if ($modulename) { $modulename } else { 'Unknown module' }
    $msg += " requires administrative rights to run"
    Write-Warning $msg
    Write-Error $msg
    break
}

function Set-BasePath {
    # .ExternalHelp AppSenseDesktopNowInstaller.psm1-help.xml
    Param(
        [Parameter(Mandatory=$true)]
        [string]$BasePath,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    $ret = $false
    try {
        Write-LogText "Setting base installer path to $BasePath" -TrackTime:$TrackTime.IsPresent
        $script:BASE_PATH = Convert-Path $BasePath -ErrorAction Stop
        $ret = $true
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    return $ret
}

function Get-BasePath {
    # .ExternalHelp AppSenseDesktopNowInstaller.psm1-help.xml
    [CmdletBinding()]
    Param()

    Write-LogText "Retrieving base installer path: $($script:BASE_PATH)" -TrackTime:$TrackTime.IsPresent
    return $script:BASE_PATH
}

function Add-Component {
    # .ExternalHelp AppSenseDesktopNowInstaller.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, HelpMessage='The component to install')]
        [AppSenseDesktopNow.Products]$Component,

        [Parameter(Mandatory=$false, HelpMessage='The path to the installers')]
        [string]$ComponentPath = $AppSenseDefaults.Installer.ComponentPath,

        [Parameter(Mandatory=$false, HelpMessage='The path to the pre-requisites')]
        [string]$PrerequisitePath = $AppSenseDefaults.Installer.PrereqPath,

        [Parameter(Mandatory=$false, HelpMessage='The name of the instance to install', ParameterSetName="Instance")]
        [string]$InstanceName = [string]::Empty,

        [Parameter(Mandatory=$false, HelpMessage='The path to the AppSense Bin folder', ParameterSetName="Instance")]
        [string]$BinPath = $AppSenseDefaults.Installer.BinPath,

        [Parameter(Mandatory=$false, HelpMessage='Any additional parameters to be passed to the installer')]
        [string[]]$SetupParams = $null,

        [Parameter(Mandatory=$false, HelpMessage='Path to the sxs folder that contains the .NET files')]
        [string]$SxSPath = [string]::Empty,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        Write-LogText "Started Add-AppSenseDesktopNowComponent" -TrackTime:$TrackTime.IsPresent
        $pathBase = Get-BasePath -Verbose:$false
        if (-not [System.IO.Path]::IsPathRooted($ComponentPath)) { $ComponentPath = Join-Path -Path $pathBase -ChildPath $ComponentPath }
        if (-not [System.IO.Path]::IsPathRooted($PrerequisitePath)) { $PrerequisitePath = Join-Path -Path $pathBase -ChildPath $PrerequisitePath }
        if (-not [System.IO.Path]::IsPathRooted($BinPath)) { $BinPath = Join-Path -Path $pathBase -ChildPath $BinPath }
        $ret = $false
        $continue = $false
        $prod = Get-Product $Component
        $jsonDetails = $jsonConfig.GetComponent($prod)
        $msiProps = Get-InstallerProperty -Path $ComponentPath\$($jsonDetails.cmd) -TrackTime:$TrackTime.IsPresent
        if (-not $msiProps) { Write-Warning "Unable to verify MSI properties - install may not work as expected" -TrackTime:$TrackTime.IsPresent }
        if ($PSCmdlet.ParameterSetName -eq 'Instance') {
            #-- check if instances are supported by the product intended for install --#
            if ($msiProps) {
                $ver = [version]$msiProps.ProductVersion
                $compver = [version]$jsonDetails.instancever
                if ($ver.CompareTo($compver) -lt 0) { Throw("The version of the product you are trying to install does not support named instances") }
            }
            #-- carry on --#
            Write-LogText "Retrieving instance installer arguments" -TrackTime:$TrackTime.IsPresent
            $iArgs = Start-ExternalProcess -WorkingDirectory $BinPath -Command (Join-Path -Path $BinPath -ChildPath "InstallerCmd.exe") -ArgumentList @('/is', "$ComponentPath\$($jsonDetails.cmd)", "`"$InstanceName`"") -ReturnStdOut  -TrackTime:$TrackTime.IsPresent -Verbose:$false
            if ($iArgs.GetType().Name -eq 'String') {
                if (-not $iArgs.StartsWith('AppSense')) {
                    if ($iArgs.Contains($jsonDetails.cmd)) {
                        $continue = $iArgs -match "TRANSFORMS=.*"
                        if ($continue) {
                            if (-not $jsonDetails.args) {
                                $iArgs = $matches[0] -split ' +(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)'
                                if ($continue) { $jsonDetails | Add-Member -Type NoteProperty -Name 'args' -Value $iArgs }
                            } else {
                                $jsonDetails.args += $matches[1].Trim()
                            }
                        }
                    } else {
                        Write-LogText $iArgs -TrackTime:$TrackTime.IsPresent
                    }
                } else {
                    Write-LogText "Invalid parameters supplied to InstallerCmd" -TrackTime:$TrackTime.IsPresent
                }
            }
        } else {
            $continue = $true
        }
        if ($continue) {
            $instArgList = @{'ProductVersion'=$([version]$msiProps.ProductVersion); 'InstallerDetails'=$jsonDetails; 'InstallerPath'=$ComponentPath; 'PrerequisitePath'=$PrerequisitePath; 'SetupParams'=$SetupParams; 'TrackTime'=$TrackTime.IsPresent}
            if ($SxSPath -ne [string]::Empty) { $instArgList.Add('SxSPath', $SxSPath) }
            $ret = Invoke-Install @instArgList
            Write-LogText "Finished Add-AppSenseDesktopNowComponent" -TrackTime:$TrackTime.IsPresent
        }
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    return $ret
}

function Update-Component {
    # .ExternalHelp AppSenseDesktopNowInstaller.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, HelpMessage='The component to install')]
        [string]$PatchPath,

        [Parameter(Mandatory=$false, HelpMessage='The name of the instance to install', ParameterSetName="Instance")]
        [string]$InstanceName = [string]::Empty,

        [Parameter(Mandatory=$false, HelpMessage='The path to the AppSense Bin folder', ParameterSetName="Instance")]
        [string]$BinPath = $AppSenseDefaults.Installer.BinPath,

        [Parameter(Mandatory=$false, HelpMessage='Any additional parameters to be passed to the installer')]
        [string[]]$SetupParams = $null,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Write-LogText "Started Update-AppSenseDesktopNowComponent" -TrackTime:$TrackTime.IsPresent
    $pathBase = Get-BasePath -Verbose:$false
    if (-not [System.IO.Path]::IsPathRooted($PatchPath)) { $PatchPath = Join-Path -Path $pathBase -ChildPath "$($AppSenseDefaults.Installer.ComponentPath)\$PatchPath" }
    if (-not [System.IO.Path]::IsPathRooted($BinPath)) { $BinPath = Join-Path -Path $pathBase -ChildPath $BinPath }
    $ret = $false
    $continue = $false
    $jsonDetails = $jsonConfig.GetSection("windowsinstaller")
    if ($PSCmdlet.ParameterSetName -eq 'Instance') {
        Write-LogText "Retrieving instance installer arguments" -TrackTime:$TrackTime.IsPresent
        $iArgs = Start-ExternalProcess -WorkingDirectory $BinPath -Command (Join-Path -Path $BinPath -ChildPath "InstallerCmd.exe") -ArgumentList @('/ps', "$PatchPath", "`"$InstanceName`"") -ReturnStdOut -Verbose:$false
        if ($iArgs.GetType().Name -eq 'String') {
            if (-not $iArgs.StartsWith('AppSense')) {
                if ($iArgs.Contains($jsonDetails.cmd)) {
                    $continue = $iArgs -match "$([Regex]::Escape($PatchPath))"
                    if ($continue) {
                        $iArgs = $iArgs -split ' +(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)'
                        $iArgs = $iArgs[1..($iArgs.Length - 1)]
                    }
                } else {
                    Write-LogText $iArgs -TrackTime:$TrackTime.IsPresent
                }
            } else {
                Write-LogText "Invalid parameters supplied to InstallerCmd" -TrackTime:$TrackTime.IsPresent
            }
        }
    } else {
        $iArgs = "/p", $PatchPath
        $continue = $true
    }
    if ($continue) {
        $instArgList = @{'command'=$jsonDetails.cmd; 'arguments'=($iArgs + $jsonDetails.args + $SetupParams); 'TrackTime'=$TrackTime.IsPresent}
        $ret = Start-Install @instArgList
        Write-LogText "Finished Update-AppSenseDesktopNowComponent" -TrackTime:$TrackTime.IsPresent
    }
    return $ret
}

function Add-Console {
    # .ExternalHelp AppSenseDesktopNowInstaller.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, Position=1, HelpMessage='The console to install')]
        [AppSenseDesktopNow.Consoles]$Console,

        [Parameter(Mandatory=$false, Position=2, HelpMessage='The path to the installers')]
        [string]$ConsolePath = $AppSenseDefaults.Installer.ComponentPath,

        [Parameter(Mandatory=$false, Position=3, HelpMessage='The path to the pre-requisites')]
        [string]$PrerequisitePath = $AppSenseDefaults.Installer.PrereqPath,

        [Parameter(Mandatory=$false, Position=4, HelpMessage='Any additional parameters to be passed to the installer')]
        [string[]]$SetupParams = $null,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Write-LogText "Started Add-AppSenseDesktopNowConsole" -TrackTime:$TrackTime.IsPresent
    $ret = $false
    $c = Get-Console $Console
    $c += if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
    $jsonDetails = $jsonConfig.GetComponent($c)
    $pathBase = Get-BasePath -Verbose:$false
    if (-not [System.IO.Path]::IsPathRooted($ConsolePath)) { $ConsolePath = Join-Path -Path $pathBase -ChildPath $ConsolePath }
    if (-not [System.IO.Path]::IsPathRooted($PrerequisitePath)) { $PrerequisitePath = Join-Path -Path $pathBase -ChildPath $PrerequisitePath }
    $ret = Invoke-Install -InstallerDetails $jsonDetails -InstallerPath $ConsolePath -PrerequisitePath $PrerequisitePath -SetupParams $SetupParams -TrackTime:$TrackTime.IsPresent
    Write-LogText "Finished Add-AppSenseDesktopNowConsole" -TrackTime:$TrackTime.IsPresent
    return $ret
}

function Invoke-Install {
    Param(
        [Parameter(Mandatory=$true)]
        [PSObject]$InstallerDetails,

        [Parameter(Mandatory=$false, HelpMessage='The path to the installer')]
        [string]$InstallerPath = [string]::Empty,

        [Parameter(Mandatory=$false, HelpMessage='The path to the pre-requisites')]
        [string]$PrerequisitePath = [string]::Empty,

        [Parameter(Mandatory=$false, HelpMessage='Any additional parameters to be passed to the installer')]
        [string[]]$SetupParams = $null,

        [Parameter(Mandatory=$false, HelpMessage='Path to the sxs folder that contains the .NET files')]
        [string]$SxSPath = [string]::Empty,

        [Parameter(Mandatory=$false)]
        [System.Version]$ProductVersion,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    $ret = $false
    if ($InstallerDetails) {
        $continue = $true
        $msg = "Determining prerequisites for $($InstallerDetails.friendly)"
        $msg += if ($ProductVersion) { " version $($ProductVersion.ToString())" } else { "" }
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        #-- handle the windows features --#
        $ver = "{0}.{1}" -f [System.Environment]::OSVersion.Version.Major, [System.Environment]::OSVersion.Version.Minor
        Write-LogText "OS Found: $ver" -TrackTime:$TrackTime.IsPresent
        $features = $InstallerDetails.features.$ver
        if (-not $features) {
            Write-LogText "No Windows Roles and Features to be installed for this component" -TrackTime:$TrackTime.IsPresent
        } else {
            if ($ProductVersion) {
                $f = $features | Get-Member -MemberType NoteProperty
                if ($f) {
                    $iVer = $f.Name
                    for ($i=3; $i -ge 0; $i--) {
                        $v = $ProductVersion.ToString().Split('.')[0..$i] -join '.'
                        if ($v -in $iVer) {
                            $features = $features.$v
                            break
                        }
                    }
                }
            }
            try {
                if (Test-ModuleAvailability 'ServerManager' -TrackTime:$TrackTime.IsPresent) {
                    Write-LogText "Installing required Windows Roles and Features" -TrackTime:$TrackTime.IsPresent
                    Import-Module ServerManager -ErrorAction Stop -Verbose:$false
                    $awfArgList = @{"Name"=$features; "Verbose"=$false}
                    if ($SxSPath -ne [string]::Empty) { $awfArgList.Add("Source", $SxSPath) }
                    $res = Add-WindowsFeature @awfArgList -ErrorAction Stop
                    switch ([int]$res.ExitCode) {
                        0       { $msg = "Successfully installed all Windows Roles and Features" }
                        1003    { $msg = "All Windows Roles and Features already installed" }
                        3010    { $msg = "Successfully installed all Windows Roles and Features (restart required)" }
                        default { $msg = "Failed to install all Windows Roles and Features" }
                    }
                    if (@(0, 1003, 3010) -notcontains [int]$res.ExitCode) {
                        $fWRF = $res.FeatureResult | Where Success -eq $false
                        $msg += " ($($fWRF.Name -join ", "))"
                        Throw($msg.Trim())
                    }
                    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
                } else {
                    $continue = $false
                }
            } catch {
                $continue = $false
                Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            }
        }
        #-- handle pre-reqs and installation --#
        if ($continue) {
            $installers = @()
            if ($ProductVersion) {
                $iVer = ($InstallerDetails.prerequisites | Get-Member -MemberType NoteProperty).Name
                for ($i=3; $i -ge 0; $i--) {
                    $v = $ProductVersion.ToString().Split('.')[0..$i] -join '.'
                    if ($v -in $iVer) { break }
                }
                $prereqs = $InstallerDetails.prerequisites.$v
            } else {
                $prereqs = $InstallerDetails.prerequisites
            }
            foreach ($p in $prereqs) {
                $installers += $jsonConfig.GetPrerequisite($p)
            }
            $installers += $InstallerDetails
            for ($c=0;$c -lt $installers.Length;$c++) {
                $name = $installers[$c].friendly
                $ai = $false
                if ($installers[$c].check) {
                    switch ($installers[$c].check.type) {
                        "registry" {
                            $regValue = if ($installers[$c].check.value) { $installers[$c].check.value } else { "" }
                            $regData = if ($installers[$c].check.data) { $installers[$c].check.data } else { "" }
                            $regCompare = if ($installers[$c].check.compare) { $installers[$c].check.compare } else { 'eq' }
                            $ai = Test-PrerequisiteInstalled -PrerequisiteName $name -RegPath $installers[$c].check.key -RegValue $regValue -RegData $regData -RegCompare $regCompare -TrackTime:$TrackTime.IsPresent
                        }
                        "product" {
                            $ai = Test-PrerequisiteInstalled -PrerequisiteName $name -ProductCode $installers[$c].check.code -TrackTime:$TrackTime.IsPresent
                        }
                    }
                }
                if (-not $ai) {
                    Write-LogText "Installing $name" -TrackTime:$TrackTime.IsPresent
                    $arglist = @()
                    if ($installers[$c].windowsinstaller) {
                        $wi = $jsonConfig.GetSection("windowsinstaller")
                        $cmd = $wi.cmd
                        $arglist += @('/i', $installers[$c].cmd) + $wi.args
                    } else {
                        $cmd = Join-Path -Path $PrerequisitePath -ChildPath $installers[$c].cmd
                    }
                    if ($installers[$c].args) { $arglist += $installers[$c].args }
                    if ($c -eq $installers.Length - 1) {
                        if ($SetupParams) { $arglist += $SetupParams }
                        $wd = $InstallerPath
                    } else {
                        $wd = $PrerequisitePath
                    }
                    $e = Start-Install $cmd $arglist $wd -TrackTime:$TrackTime.IsPresent
                    if ($e -eq $true) {
                        $ret = $true
                    } else {
                        $ret = $false
                        break
                    }
                }
            }
        }
    }
    return $ret
}

function Start-Install([string]$command, [string[]]$arguments, [string]$ExecutableDirectory = [string]::Empty, [switch]$TrackTime) {
    $ret = $false
    $e = Start-ExternalProcess -Command $command -ArgumentList $arguments -WorkingDirectory $ExecutableDirectory -TrackTime:$TrackTime.IsPresent -ReturnExitCode
    if ($e -eq 0 -or $e -eq 1641 -or $e -eq 3010) { $ret = $true }
    return $ret
}

Export-ModuleMember -Function Set-BasePath, Get-BasePath, Add-Component, Update-Component, Add-Console, Set-LogPath