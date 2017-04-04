. $PSScriptRoot\requiredassemblies.ps1 @($AppSenseDefaults.ManagementServer.WebServicesDLL, $AppSenseDefaults.ManagementServer.PackageManagerDLL)

Add-Type -TypeDefinition @"
    namespace AppSenseDesktopNow {
        public enum PackageTypes { Agent, Configuration }
    }
"@

$PKG_MGR = $null
$AMC_ATTEMPTED = $false

function Connect-PackageServer {
    # .ExternalHelp AppSenseDesktopNowAMCPackages.psm1-help.xml
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
        Write-LogText "Connecting to the Package Management Server as $user" -TrackTime:$TrackTime.IsPresent
        $script:PKG_MGR = [PackageManagement.PackageServerFactory]::GetPackageServer($url, $creds)
        $ret = $true
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    $msg = if ($ret) { "Successfully connected " } else { "Failed to connect " }
    $msg += "to the Package Management Server"
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    if ($ret -and (-not $script:AMC_ATTEMPTED) -and ($MyInvocation.InvocationName -ne '&')) {
        $script:AMC_ATTEMPTED = $true
        $prefix = Get-ModuleDetails -Path "$PSScriptRoot\AppSenseDesktopNowAMCServer" -Property 'Prefix' -TrackTime:$TrackTime.IsPresent -Verbose:$false
        $cmdlet = "Connect-{0}Server" -f $prefix
        if (Get-Command -Name $cmdlet -ErrorAction SilentlyContinue) { $ret = & $cmdlet @PSBoundParameters }
    }
    return $ret
}

function Get-Package {
    # .ExternalHelp AppSenseDesktopNowAMCPackages.psm1-help.xml
    [CmdletBinding(DefaultParameterSetName='All')]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName='ByKey')]
        [string]$PackageKey,

        [Parameter(Mandatory=$false, ParameterSetName='All')]
        [Parameter(Mandatory=$false, ParameterSetName='LatestVersion')]
        [Parameter(Mandatory=$false, ParameterSetName='ByVersion')]
        [string]$Product,

        [Parameter(Mandatory=$false, ParameterSetName='All')]
        [Parameter(Mandatory=$false, ParameterSetName='LatestVersion')]
        [Parameter(Mandatory=$false, ParameterSetName='ByVersion')]
        [string]$Name,

        [Parameter(Mandatory=$false, ParameterSetName='All')]
        [Parameter(Mandatory=$false, ParameterSetName='LatestVersion')]
        [Parameter(Mandatory=$false, ParameterSetName='ByVersion')]
        [AppSenseDesktopNow.PackageTypes]$Type,

        [Parameter(Mandatory=$false, ParameterSetName='All')]
        [Parameter(Mandatory=$false, ParameterSetName='LatestVersion')]
        [Parameter(Mandatory=$false, ParameterSetName='ByVersion')]
        [ManagementConsole.PackagesWebService.PackagePlatform]$Platform,

        [Parameter(Mandatory=$true, ParameterSetName='ByVersion')]
        [System.Version]$Version,

        [Parameter(Mandatory=$true, ParameterSetName='LatestVersion')]
        [switch]$LatestVersion,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        Write-LogText "Retrieving packages" -TrackTime:$TrackTime.IsPresent
        if (-not $script:PKG_MGR -or -not [ManagementConsole.WebServices]::Packages) { Throw('Please ensure that you are connected to the Package Management Server') }
        if ($PSCmdlet.ParameterSetName.StartsWith('ByKey')) {
            $dsPackages = [ManagementConsole.WebServices]::Packages.GetPackageFromKey($PackageKey)
            if (-not $dsPackages.Packages.Rows.Count) { Throw('No matching package found') }
        } else {
            $dsPackages = [ManagementConsole.WebServices]::Packages.GetPackages()
        }
        $pkgs = @()
        foreach ($p in $dsPackages.Packages) {
            $pv = $dsPackages.PackageVersions | Where PackageKey -eq $p.PackageKey | Sort Major,Minor,Build,Revision -Descending
            $pkgs += $pv #add base packages to the array
            if ($p.Type -eq 'msi/agent') {
                if ($dsPackages.Patches.Rows.Count) {
                    $patches = $dsPackages.Patches | Where PackageVersionKey -eq $pv.PackageVersionKey | Sort Major,Minor,Build,Revision -Descending
                    if ($patches) { $pkgs += $patches }
                }
            }
        }
        $pkgs = Get-PkgObjectFromPackagesDataset -PackagesDataSet $pkgs
        if ($Product) { $pkgs = $pkgs | Where ProductName -eq $Product }
        if ($Name) { $pkgs = $pkgs | Where Name -like "*$Name*" }
        if ($Type) { $pkgs = $pkgs | Where Type -eq (Get-PkgType -PackageType $Type).Type }
        if ($Platform) { $pkgs = $pkgs | Where Platform -eq $Platform }
        if ($Version) { $pkgs = $pkgs | Where { $_.BaseVersion -eq $Version -or $_.Version -eq $Version } }
        if ($LatestVersion) { $pkgs = $pkgs | Sort BaseVersion,Version -Descending | Group Name | % { $_ | Select -Expand Group | Select -First 1 } }
        $ret = if ($pkgs) { $pkgs } else { $false }
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    if (-not $Version -and -not $LatestVersion.IsPresent) {
        $n = if ($ret) { $ret.Packages.Rows.Count } else { 0 }
    } else {
        $n = if ($ret) { if ($ret.Count) { $ret.Count } else { 1 } } else { 0 }
    }
    $msg = "$n package"
    if ($n -ne 1) { $msg += "s" }
    if (-not $Version -and -not $LatestVersion.IsPresent) {
        $n = if ($ret) { $ret.PackageVersions.Count } else { 0 }
        $msg += " with $n version"
        if ($n -ne 1) { $msg += "s" }
        $n = if ($ret) { $ret.Patches.Rows.Count } else { 0 }
        $msg += " and $n patch"
        if ($n -ne 1) { $msg += "es" }
    }
    $msg += " match"
    if ($n -eq 1 -and $Version -or $LatestVersion.IsPresent) { $msg += "es" }
    $msg += " the specified criteria"
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

function Lock-Package {
    # .ExternalHelp AppSenseDesktopNowAMCPackages.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$PackageKey,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        Write-LogText "Locking package $PackageKey" -TrackTime:$TrackTime.IsPresent
        [ManagementConsole.WebServices]::Packages.LockPackage($PackageKey)
        $ret = $true
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    $msg = if ($ret) { "Successfully locked " } else { "Failed to lock " }
    $msg += $PackageKey
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

function Unlock-Package {
    # .ExternalHelp AppSenseDesktopNowAMCPackages.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$PackageKey,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        Write-LogText "Unlocking package $PackageKey" -TrackTime:$TrackTime.IsPresent
        [ManagementConsole.WebServices]::Packages.UnlockPackage($PackageKey)
        $ret = $true
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    $msg = if ($ret) { "Successfully unlocked " } else { "Failed to unlock " }
    $msg += $PackageKey
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

function Import-Package {
    # .ExternalHelp AppSenseDesktopNowAMCPackages.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$PackagePath,

        [Parameter(Mandatory=$false)]
        [string]$PrerequisitePath = '.',

        [Parameter(Mandatory=$false)]
        [string]$Description = $AppSenseDefaults.Packages.Description,

        [Parameter(Mandatory=$false)]
        [int]$ChunkSizeBytes = $AppSenseDefaults.Packages.ChunkSize,

        [Parameter(Mandatory=$false)]
        [switch]$ResetVersion,

        [Parameter(Mandatory=$false)]
        [switch]$ShowProgress,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        Write-LogText "Importing $PackagePath" -TrackTime:$TrackTime.IsPresent
        if (-not $script:PKG_MGR) { Throw('Please ensure that you are connected to the Package Management Server') }
        $ret = $false
        if ([System.IO.Path]::GetExtension($PackagePath).ToLower() -eq '.msp') {
            $argsIP = @{'PackagePath'=$PackagePath; 'Description'=$Description; 'ChunkSizeBytes'=$ChunkSizeBytes; 'ShowProgress'=$ShowProgress.IsPresent; 'TrackTime'=$TrackTime.IsPresent}
            $ret = Import-Patch @argsIP
        } elseif ([System.IO.Path]::GetExtension($PackagePath).ToLower() -eq '.msi') {
            $props = @("UpgradeCode", "ProductCode", "Manufacturer", "PackageType", "ProductKey", "ProductVersion", "ConfigName", "ProductTitle", "ProductName", "AppSense_Platform", "CreatorVersion", "DependantMinimumVersion", "DependantMaximumVersion", "APPSENSE_SUPPORTSMIDSESSIONUPDATE")
            $pkgProperties = Get-InstallerProperty -Path $PackagePath -Properties $props -TrackTime:$TrackTime.IsPresent
            if ($pkgProperties) {
                #-- fix up some properties --#
                $pkgProperties.SupporsMidsessionUpdate = [System.Convert]::ToBoolean($pkgProperties.APPSENSE_SUPPORTSMIDSESSIONUPDATE)
                if ($pkgProperties.PackageType -eq 'Config') {
                    $pkgProperties.PackageType = 'Configuration'
                    $pkgProperties.Add('ProductTitle', $pkgProperties.ConfigName)
                }
                if ($ResetVersion.IsPresent) {
                    if ($pkgProperties.PackageType -eq 'Configuration') {
                        $t = New-Object System.Version($pkgProperties.ProductVersion)
                        $pkgProperties.ProductVersion = "{0}.{1}.0.0" -f $t.Major, $t.Minor
                    } else {
                        Write-Warning "ResetVersion switch is not valid for configuration packages - ignoring switch parameter"
                    }
                }
                if (-not ($pkgProperties.ContainsKey('AppSense_Platform'))) { $pkgProperties.Add("AppSense_Platform", "Independant") }
                if (-not ($pkgProperties.ContainsKey('CreatorVersion'))) { $pkgProperties.Add("CreatorVersion", "0.0.0.0") }
                if (-not ($pkgProperties.ContainsKey('DependantMinimumVersion'))) { $pkgProperties.Add("DependantMinimumVersion", "0.0.0.0") }
                if (-not ($pkgProperties.ContainsKey('DependantMaximumVersion'))) { $pkgProperties.Add("DependantMaximumVersion", "0.0.0.0") }
                foreach ($v in $pkgProperties.Clone().GetEnumerator()) {
                    if ($v.Key.EndsWith('Version')) {
                        $t = [version]$v.Value
                        if ($t.Build -eq -1) {
                            $pkgProperties[$v.Key] = "$($v.Value.ToString()).0.0"
                        } elseif ($t.Revision -eq -1) {
                            $pkgProperties[$v.Key] = "$($v.Value.ToString()).0"
                        }
                    }
                }
                #-- get additional propertites --#
                $xmlProperties = Get-InstallerMetadata -Path $PackagePath -MetadataName "Product.xml" -TrackTime:$TrackTime.IsPresent
                if ($xmlProperties) {
                    $objXml = New-Object -TypeName System.Xml.XmlDocument
                    $objXml.LoadXml($xmlProperties)
                    $props = @("Name", "Icon", "SupportsAgents", "SupportsConfigurations", "SupportsSoftware", "AlertRules", "EventDefinitions", "ReportPack")
                    foreach ($p in $props) {
                        try {
                            $pv = [System.Convert]::ToBoolean($objXml.ProductPack.$p)
                        } catch [FormatException] {
                            $pv = $objXml.ProductPack.$p
                        }
                        if ($objXml.ProductPack.$p) {
                            if ($pkgProperties.ContainsKey($p)) { $pkgProperties.Add("XML_$p", $pv) } else { $pkgProperties.Add($p, $pv) }
                        }
                    }
                }
            }
            #-- does the product exist --#
            $prefix = Get-ModuleDetails -Path "$PSScriptRoot\AppSenseDesktopNowAMCProducts" -Property 'Prefix' -TrackTime:$TrackTime.IsPresent -Verbose:$false
            $args = @{'ProductKey'=$pkgProperties.ProductKey; 'TrackTime'=$TrackTime.IsPresent; 'Verbose'=$false}
            $cmdlet = "Get-{0}Product" -f $prefix
            Write-LogText "Checking if the product needs to be created" -TrackTime:$TrackTime.IsPresent
            $exists = & $cmdlet @args
            if (-not $exists) {
                Write-LogText "Product needs to be created" -TrackTime:$TrackTime.IsPresent
                $msiIcon = Get-InstallerMetadata -Path $PackagePath -MetadataName $pkgProperties.Icon -TrackTime:$TrackTime.IsPresent
                $args = @{'ProductKey'=$pkgProperties.ProductKey; 'ProductName'=$pkgProperties.Name; 'IconString'=$msiIcon; 'SupportsSoftware'=$pkgProperties.SupportsSoftware; 'SupportsConfigurations'=$pkgProperties.SupportsConfigurations; 'SupportsAgents'=$pkgProperties.SupportsConfigurations; 'TrackTime'=$TrackTime.IsPresent; 'Verbose'=$VerbosePreference}
                $cmdlet = "Set-{0}Product" -f $prefix
                $created = & $cmdlet @args
                if ($created) {
                    $args = @{'ProductKey'=$pkgProperties.ProductKey; 'TrackTime'=$TrackTime.IsPresent; 'Verbose'=$false}
                    $cmdlet = "Get-{0}Product" -f $prefix
                    $exists = & $cmdlet @args
                } else {
                    Throw('Failed to create the product')
                }
            } else {
                Write-LogText "No need to create the product" -TrackTime:$TrackTime.IsPresent
            }
            #-- is it a licensing package? --#
            if ($exists.Name -eq 'Licensing') {
                $argsIL = @{'PackagePath'=$PackagePath; 'TrackTime'=$TrackTime.IsPresent}
                $ret = Import-License @argsIL
            } else {
                #-- does the package exist? --#
                $createVersion = $false
                Write-LogText "Checking if the package needs to be created" -TrackTime:$TrackTime.IsPresent
                $exists = Get-Package -PackageKey $pkgProperties.UpgradeCode -TrackTime:$TrackTime.IsPresent -Verbose:$false
                if (-not $exists) {
                    Write-LogText "The package needs to be created" -TrackTime:$TrackTime.IsPresent
                    $created = [ManagementConsole.WebServices]::Packages.CreatePackage($pkgProperties.UpgradeCode, $pkgProperties.Manufacturer, `
                                                                                       (Get-PkgType -PackageType $([byte][AppSenseDesktopNow.PackageTypes]::$($pkgProperties.PackageType))).Type, `
                                                                                       (Get-PkgPlatform -PackagePlatform $pkgProperties.AppSense_Platform), $pkgProperties.ProductKey)
                    if (-not $created) { Throw('Failed to create package') }
                    $createVersion = $true
                } else {
                    Write-LogText "No need to create the package" -TrackTime:$TrackTime.IsPresent
                }
                #-- does the package version exist? --#
                if (-not $createVersion) {
                    Write-LogText "Checking if the package version already exists" -TrackTime:$TrackTime.IsPresent
                    $exists = Get-Package -PackageKey $pkgProperties.UpgradeCode -Version $pkgProperties.ProductVersion -TrackTime:$TrackTime.IsPresent -Verbose:$false
                    if (-not $exists) { $createVersion = $true }
                }
                if ($createVersion) {
                    Write-LogText "Creating the new package version" -TrackTime:$TrackTime.IsPresent
                    $verProduct = New-Object System.Version($pkgProperties.ProductVersion)
                    $verCreator = New-Object System.Version($pkgProperties.CreatorVersion)
                    $verDepMin = New-Object System.Version($pkgProperties.DependantMinimumVersion)
                    $verDepMax = New-Object System.Version($pkgProperties.DependantMaximumVersion)
                    $pkgName = if ((Get-PkgPlatform -PackagePlatform $pkgProperties.AppSense_Platform) -eq [ManagementConsole.PackagesWebService.PackagePlatform]::Platform64) { "$($pkgProperties.ProductTitle) (x64)" } else { $pkgProperties.ProductTitle }
                    $argsCPV = @($pkgProperties.UpgradeCode, $pkgProperties.ProductCode, $pkgName, `
                                 $verProduct.Major, $verProduct.Minor, $verProduct.Build, $verProduct.Revision, `
                                 $verCreator.Major, $verCreator.Minor, $verCreator.Build, $verCreator.Revision, `
                                 $verDepMin.Major, $verDepMin.Minor, $verDepMin.Build, $verDepMin.Revision, `
                                 $verDepMax.Major, $verDepMax.Minor, $verDepMax.Build, $verDepMax.Revision, `
                                 $Description)
                    if ($global:MS_VER.CompareTo((New-Object System.Version('8.7'))) -ge 0) { $argsCPV += [int]$pkgProperties.SupporsMidsessionUpdate }
                    $p = Get-ModuleDetails -Path "$PSScriptRoot\AppSenseDesktopNowAMCServer" -Property 'Prefix' -TrackTime:$TrackTime.IsPresent -Verbose:$false
                    $cmdlet = "Invoke-{0}ServerMethod" -f $p
                    $argsISM = @{'DataAccessEndpoint'='Packages'; 'MethodName'='CreatePackageVersion'; 'MethodArguments'=$argsCPV; 'TrackTime'=$TrackTime.IsPresent; 'Verbose'=$false}
                    $pkgModTime = & $cmdlet @argsISM
                    if ($pkgModTime) {
                        Write-LogText "Uploading $pkgName version $verProduct" -TrackTime:$TrackTime.IsPresent
                        $pkgSize = ([System.IO.FileInfo] $PackagePath).Length
                        $keyUpload = [ManagementConsole.WebServices]::Packages.BeginPackageVersionUpload($pkgProperties.UpgradeCode, $Description, $pkgProperties.ProductCode, $pkgSize, [ref] (ConvertFrom-TimeToLocal $pkgModTime))
                        $pkgFile = [System.IO.File]::OpenRead($PackagePath)
                        $bytesUploaded = 0
                        do {
                            if ($ShowProgress.IsPresent) { Write-Progress -Activity "Uploading Package" -Status "$pkgName version $verProduct" -PercentComplete (($bytesUploaded / $pkgSize) * 100) }
                            if ($ChunkSizeBytes -gt ($pkgSize - $bytesUploaded)) { $bytesToRead = $pkgSize - $bytesUploaded } else { $bytesToRead = $ChunkSizeBytes }
                            if ($bytesToRead -ne 0) {
                                $pkgBuffer = New-Object byte[] $bytesToRead
                                $pkgModTime = ConvertFrom-TimeToLocal $pkgModTime
                                $bytesRead = $pkgFile.Read($pkgBuffer, 0, $bytesToRead)
                                if ($bytesRead -ne 0) {
                                    [ManagementConsole.WebServices]::Packages.ContinuePackageVersionUpload($pkgProperties.ProductCode, [ref] $pkgModTime, $keyUpload, $bytesUploaded, $pkgBuffer)
                                    $bytesUploaded += $bytesRead
                                }
                            }
                        } until ($bytesRead -eq 0 -or $bytesToRead -eq 0)
                        if ($ShowProgress.IsPresent) { Write-Progress -Activity "Uploading Package" -Completed }
                        $pkgFile.Close()
                        [ManagementConsole.WebServices]::Packages.FinalisePackageVersion($pkgProperties.ProductCode)
                        [ManagementConsole.WebServices]::Packages.CommitPackageVersion($pkgProperties.ProductCode)
                        $ret = Unlock-Package -PackageKey $pkgProperties.UpgradeCode -TrackTime:$TrackTime.IsPresent
                    }
                    #-- Pre-reqs? --#
                    if ($ret) {
                        Write-LogText "Determining pre-requisites for $pkgName version $verProduct" -TrackTime:$TrackTime.IsPresent
                        $xmlPrereq = Get-InstallerMetadata -Path $PackagePath -MetadataName "Prerequisites.xml" -TrackTime:$TrackTime.IsPresent
                        if ($xmlPrereq) {
                            $prefix = Get-ModuleDetails -Path "$PSScriptRoot\AppSenseDesktopNowAMCPrereqs" -Property 'Prefix' -TrackTime:$TrackTime.IsPresent -Verbose:$false
                            $dsPrereqs = [ManagementConsole.WebServices]::Packages.GetPrerequisitesFromXml($xmlPrereq)
                            if ($dsPrereqs) {
                                $args = @{'Prerequisites'=$dsPrereqs; 'Path'=$PrerequisitePath; 'PackageVersionKey'=$pkgProperties.ProductCode; 'ShowProgress'=$ShowProgress.IsPresent; 'TrackTime'=$TrackTime.IsPresent; 'Verbose'=$VerbosePreference}
                                $cmdlet = "Import-{0}Prerequisite" -f $prefix
                                $ret = & $cmdlet @args
                            }
                        }
                    }
                } else {
                    Write-LogText "Package version already exists" -TrackTime:$TrackTime.IsPresent
                    $ret = $true
                }
            }
        }
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    $msg = if ($ret) { "Successfully imported " } else { "Failed to import " }
    $msg += $PackagePath
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

function Import-License {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$PackagePath,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $true
        $licDetails = Get-InstallerProperty -Path $PackagePath -Table "Registry" -KeyColumn "Name" -ValueColumn "Value" -TrackTime:$TrackTime.IsPresent
        $licDetails = $licDetails.GetEnumerator() | Where { $_.Name -ne '*' -and $_.Name -ne 'Config Format'}
        $prefix = Get-ModuleDetails -Path "$PSScriptRoot\AppSenseDesktopNowAMCLicenses" -Property 'Prefix' -TrackTime:$TrackTime.IsPresent -Verbose:$false
        $cmdlet = "Set-{0}License" -f $prefix
        foreach($l in $licDetails) {
            $argsSL = @{'LicenseCode'=$l.Name; 'ActivationCode'=$l.Value; 'TrackTime'=$TrackTime.IsPresent; 'Verbose'=$VerbosePreference}
            $e = & $cmdlet @argsSL
            if (-not $e) { $ret = $e }
        }
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    return $ret
}

function Import-Patch {
    # .ExternalHelp AppSenseDesktopNowAMCPackages.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$PackagePath,

        [Parameter(Mandatory=$false)]
        [string]$Description = $AppSenseDefaults.Packages.Description,

        [Parameter(Mandatory=$false)]
        [int]$ChunkSizeBytes = $AppSenseDefaults.Packages.ChunkSize,

        [Parameter(Mandatory=$false)]
        [switch]$ShowProgress,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        if (-not ([ManagementConsole.WebServices]::Packages | Get-Member -Name 'CreatePatch')) { Throw('Patches are not supported on this version of Management Server') }
        $pkgProperties = @{'PatchKey'=[guid]::NewGuid(); 'ValidationFlags'=0}
        $argsSI = @{'Path'=$PackagePath; 'Property'=7,9; 'TrackTime'=$TrackTime.IsPresent}
        $si = Get-InstallerSummaryInfoStream @argsSI
        $pkgProperties.Add('PatchCode', $si[1])
        $pkgProperties.Add('PackageVersionKey', $si[0])
        $props = @('DisplayName', 'APPSENSE_SUPPORTSMIDSESSIONUPDATE')
        $pkgMeta = Get-InstallerProperty -Path $PackagePath -Properties $props -Table "MsiPatchMetadata" -TrackTime:$TrackTime.IsPresent
        $pkgProperties.Name = $pkgMeta.DisplayName
        $pkgProperties.SupporsMidsessionUpdate = [System.Convert]::ToBoolean($pkgMeta.APPSENSE_SUPPORTSMIDSESSIONUPDATE)
        $argsXML = @{'Path'=$PackagePath; 'TrackTime'=$TrackTime.IsPresent}
        $xmlString = Get-InstallerPatchXMLData @argsXML
        if ($xmlString -is [System.Xml.XmlDocument]) {
            $pkgProperties.Add('PackageKey', $xmlString.MsiPatch.TargetProduct.UpgradeCode.'#text')
            $pkgProperties.Add('TargetVersion', (New-Object System.Version($xmlString.MsiPatch.TargetProduct.TargetVersion.'#text')))
            $pkgProperties.Add('Version', (New-Object System.Version($xmlString.MsiPatch.TargetProduct.UpdatedVersion)))
            Write-LogText "Checking if patch already exists" -TrackTime:$TrackTime.IsPresent
            $exists = Get-Package -PackageKey $pkgProperties.PackageKey -TrackTime:$TrackTime.IsPresent -Verbose:$false
            if (-not $exists) { Throw('Base package for this patch is not available') }
            $exists = $exists.Patches | Where PatchCode -eq $pkgProperties.PatchCode
            if ($exists) {
                Write-LogText "Patch already exists" -TrackTime:$TrackTime.IsPresent
                $ret = $true
            } else {
                Write-LogText "Patch does not exist" -TrackTime:$TrackTime.IsPresent
                $argsCP = @($pkgProperties.PatchKey.ToString(), $pkgProperties.PatchCode, $pkgProperties.PackageVersionKey, $pkgProperties.Name, `
                            $pkgProperties.Version.Major, $pkgProperties.Version.Minor, $pkgProperties.Version.Build, $pkgProperties.Version.Revision, `
                            $pkgProperties.TargetVersion.Major, $pkgProperties.TargetVersion.Minor, $pkgProperties.TargetVersion.Build, $pkgProperties.TargetVersion.Revision, `
                            $pkgProperties.ValidationFlags, $Description)
                if ($global:MS_VER.CompareTo((New-Object System.Version('8.7'))) -ge 0) { $argsCP += [int]$pkgProperties.SupporsMidsessionUpdate }
                $p = Get-ModuleDetails -Path "$PSScriptRoot\AppSenseDesktopNowAMCServer" -Property 'Prefix' -TrackTime:$TrackTime.IsPresent -Verbose:$false
                $cmdlet = "Invoke-{0}ServerMethod" -f $p
                $argsISM = @{'DataAccessEndpoint'='Packages'; 'MethodName'='CreatePatch'; 'MethodArguments'=$argsCP; 'TrackTime'=$TrackTime.IsPresent; 'Verbose'=$false}
                $pkgModTime = & $cmdlet @argsISM
                if ($pkgModTime) {
                    Write-LogText "Uploading $($pkgProperties.Name) version $($pkgProperties.Version)" -TrackTime:$TrackTime.IsPresent
                    $pkgSize = ([System.IO.FileInfo] $PackagePath).Length
                    $keyUpload = [ManagementConsole.WebServices]::Packages.BeginPatchUpload($pkgProperties.PatchKey, $Description, $pkgSize, [ref]$pkgModTime)
                    $pkgFile = [System.IO.File]::OpenRead($PackagePath)
                    $bytesUploaded = 0
                    do {
                        if ($ShowProgress.IsPresent) { Write-Progress -Activity "Uploading Patch" -Status "$($pkgProperties.Name) version $($pkgProperties.Version)" -PercentComplete (($bytesUploaded / $pkgSize) * 100) }
                        if ($ChunkSizeBytes -gt ($pkgSize - $bytesUploaded)) { $bytesToRead = $pkgSize - $bytesUploaded } else { $bytesToRead = $ChunkSizeBytes }
                        if ($bytesToRead -ne 0) {
                            $pkgBuffer = New-Object byte[] $bytesToRead
                            $pkgModTime = ConvertFrom-TimeToLocal $pkgModTime
                            $bytesRead = $pkgFile.Read($pkgBuffer, 0, $bytesToRead)
                            if ($bytesRead -ne 0) {
                                [ManagementConsole.WebServices]::Packages.ContinuePatchUpload($pkgProperties.PatchKey, [ref] $pkgModTime, $keyUpload, $bytesUploaded, $pkgBuffer)
                                $bytesUploaded += $bytesRead
                            }
                        }
                    } until ($bytesRead -eq 0 -or $bytesToRead -eq 0)
                    if ($ShowProgress.IsPresent) { Write-Progress -Activity "Uploading Patch" -Completed }
                    $pkgFile.Close()
                    [ManagementConsole.WebServices]::Packages.CommitPatch($pkgProperties.PatchKey)
                    $ret = $true
                }
            }
        }
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    return $ret
}

function Export-Package {
    # .ExternalHelp AppSenseDesktopNowAMCPackages.psm1-help.xml
    [CmdletBinding(DefaultParameterSetName='All')]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$DestinationFolder,

        [Parameter(Mandatory=$false)]
        [int]$ChunkSizeBytes = $AppSenseDefaults.Packages.ChunkSize,

        [Parameter(Mandatory=$true, ParameterSetName='ByKey')]
        [string]$PackageKey,

        [Parameter(Mandatory=$false, ParameterSetName='All')]
        [Parameter(Mandatory=$false, ParameterSetName='LatestVersion')]
        [Parameter(Mandatory=$false, ParameterSetName='ByVersion')]
        [string]$Product,

        [Parameter(Mandatory=$false, ParameterSetName='All')]
        [Parameter(Mandatory=$false, ParameterSetName='LatestVersion')]
        [Parameter(Mandatory=$false, ParameterSetName='ByVersion')]
        [string]$Name,

        [Parameter(Mandatory=$false, ParameterSetName='All')]
        [Parameter(Mandatory=$false, ParameterSetName='LatestVersion')]
        [Parameter(Mandatory=$false, ParameterSetName='ByVersion')]
        [AppSenseDesktopNow.PackageTypes]$Type,

        [Parameter(Mandatory=$false, ParameterSetName='All')]
        [Parameter(Mandatory=$false, ParameterSetName='LatestVersion')]
        [Parameter(Mandatory=$false, ParameterSetName='ByVersion')]
        [ManagementConsole.PackagesWebService.PackagePlatform]$Platform,

        [Parameter(Mandatory=$true, ParameterSetName='ByVersion')]
        [System.Version]$Version,

        [Parameter(Mandatory=$true, ParameterSetName='LatestVersion')]
        [switch]$LatestVersion,

        [Parameter(Mandatory=$false)]
        [switch]$IncludeBase,

        [Parameter(Mandatory=$false)]
        [switch]$IncludePrerequisites,

        [Parameter(Mandatory=$false)]
        [switch]$ShowProgress,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $params = @{} + $PSBoundParameters
        $params = Get-MatchingCmdletParameters -Cmdlet 'Get-Package' -CurrentParameters $params
        $pkgs = Get-Package @params
        if ($pkgs) {
            foreach ($p in $pkgs) {
                if ($p.PatchKey) {
                    $ext = 'msp'
                    $v = $p.Version
                    $pKey = $p.PatchKey
                } else {
                    $ext = 'msi'
                    $v = $p.BaseVersion
                    $pKey = $p.PackageKey
                }
                $dest = "{0}\{1}_{2}.{3}" -f $DestinationFolder, $p.Name, $v, $ext
                if (-not (Test-Path -Path $dest)) {
                    $ret = Export-Pkg -PackageKey $pKey -PackageName $p.Name -PackageVersion $v -Destination $dest
                    if (-not $ret) { Throw('Error exporting package') }
                } else {
                    Write-LogText "$dest already exists - skipping" -TrackTime:$TrackTime.IsPresent
                    $ret = $true
                }
                if ($ret) {
                    #-- do we need to export the base package as well --#
                    if ($p.PatchKey -and $IncludeBase.IsPresent) {
                        $dest = "{0}\{1}_{2}.{3}" -f $DestinationFolder, $p.Name, $p.BaseVersion, 'msi'
                        if (-not (Test-Path -Path $dest)) {
                            Write-LogText "Exporting base package for patch to $dest" -TrackTime:$TrackTime.IsPresent
                            $ret = Export-Pkg -PackageKey $p.PackageKey -PackageName $p.Name -PackageVersion $p.BaseVersion -Destination $dest
                        } else {
                            Write-LogText "$dest already exists - skipping" -TrackTime:$TrackTime.IsPresent
                        }
                    }
                    #-- do we need to export the prerequisites --#
                    if ($ret -and $IncludePrerequisites.IsPresent -and $p.Type -eq 'msi/agent') {
                        $prefix = Get-ModuleDetails -Path "$PSScriptRoot\AppSenseDesktopNowAMCPrereqs" -Property 'Prefix' -TrackTime:$TrackTime.IsPresent -Verbose:$false
                        $cmdlet = "Export-{0}Prerequisite" -f $prefix
                        $args = @{'DestinationFolder'=$DestinationFolder; 'PackageVersionKey'=$p.PackageVersionKey; 'ChunkSizeBytes'=$ChunkSizeBytes; 'ShowProgress'=$ShowProgress.IsPresent; 'TrackTime'=$TrackTime.IsPresent}
                        $ret = & $cmdlet @args
                        if (-not $ret) { Throw 'Error exporting prerequisite' }
                    }
                }
            }
            $ret = $true
        }
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    return $ret
}

function Get-PkgType {
    Param(
        [Parameter(Mandatory=$true)]
        [byte]$PackageType
    )

    try {
        $ret = $false
        $pkgs = @(
            @{'Type'='msi/agent'},
            @{'Type'='msi/configuration'}
        )
        $ret = $pkgs[$PackageType]
    } catch {
        $ret = $false
    }
    return $ret
}

function Get-PkgPlatform {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$PackagePlatform
    )

    try {
        $ret = $false
        $str = if ($PackagePlatform -ne 'Independant') { $PackagePlatform -replace "\D", "" } else { $PackagePlatform }
        $enumVal = [System.Enum]::GetNames("ManagementConsole.PackagesWebService.PackagePlatform") -match $str
        $ret = [int][ManagementConsole.PackagesWebService.PackagePlatform]::$enumVal
    } catch {
        $ret = $false
    }
    return $ret
}

function Get-PkgVersions {
    Param(
        [Parameter(Mandatory=$true)]
        [ManagementConsole.PackagesWebService.PackagesDataSet+PackageVersionsRow[]]$PackageVersions,

        [Parameter(Mandatory=$true)]
        [string[]]$PackageKey
    )

    $ret = $PackageVersions | Where PackageKey -in (Select -InputObject $PackageKey -Unique)
    return $ret
}

function Get-PkgPatches {
    Param(
        [Parameter(Mandatory=$true)]
        [ManagementConsole.PackagesWebService.PackagesDataSet+PatchesRow[]]$PackagePatches,

        [Parameter(Mandatory=$true)]
        [string[]]$PackageVersionKey
    )

    $ret = $PackagePatches | Where PackageVersionKey -in (Select -InputObject $PackageVersionKey -Unique)
    return $ret
}

function Get-PkgDataset {
    Param(
        [Parameter(Mandatory=$true)]
        [ManagementConsole.PackagesWebService.PackagesDataSet+PackagesRow[]]$Packages,

        [Parameter(Mandatory=$true)]
        [ManagementConsole.PackagesWebService.PackagesDataSet+PackageVersionsRow[]]$PackageVersions,

        [Parameter(Mandatory=$true)]
        [AllowNull()]
        [ManagementConsole.PackagesWebService.PackagesDataSet+PatchesRow[]]$PackagePatches
    )

    $ret = New-Object ManagementConsole.PackagesWebService.PackagesDataSet
    foreach ($p in $Packages) { $ret.Packages.ImportRow($p) }
    foreach ($p in $PackageVersions) { $ret.PackageVersions.ImportRow($p) }
    if ($PackagePatches) { foreach ($p in $PackagePatches) { $ret.Patches.ImportRow($p) } }
    return $ret
}

function Export-Pkg {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$PackageKey,

        [Parameter(Mandatory=$true)]
        [string]$PackageName,

        [Parameter(Mandatory=$true)]
        [System.Version]$PackageVersion,

        [Parameter(Mandatory=$true)]
        [string]$Destination
    )

    try {
        $msg = "$PackageName $PackageVersion"
        Write-LogText "Exporting $msg to $Destination" -TrackTime:$TrackTime.IsPresent
        if ([System.IO.Path]::GetExtension($Destination).ToLower() -eq '.msp') {
            $pkgSize = [ManagementConsole.WebServices]::Packages.GetPatchLength($PackageKey)
            $title = "Patch"
        } else {
            $pkgSize = $script:PKG_MGR.GetPackageVersionLength($PackageKey, $PackageVersion.Major, $PackageVersion.Minor, $PackageVersion.Build, $PackageVersion.Revision)
            $title = "Package"
        }
        if ($pkgSize) {
            if ([System.IO.Path]::GetExtension($Destination).ToLower() -eq '.msp') {
                $dKey = [ManagementConsole.WebServices]::Packages.BeginPatchDownload($PackageKey)
            } else {
                $dKey = $script:PKG_MGR.BeginPackageVersionDownload($PackageKey, $PackageVersion.Major, $PackageVersion.Minor, $PackageVersion.Build, $PackageVersion.Revision)
            }
            if ($dKey) {
                $pkgOffset = 0
                $pkgChunk = $ChunkSizeBytes
                $fs = New-Object System.IO.FileStream($Destination, 'Create', 'Write')
                do {
                    if ($ShowProgress.IsPresent) { Write-Progress -Activity "Exporting $title" -Status $msg -PercentComplete (($pkgOffset / $pkgSize) * 100) }
                    $pkgLeft = $pkgSize - $pkgOffset
                    $pkgChunk = if ($pkgLeft -ge $pkgChunk) { $pkgChunk } else { $pkgSize - $pkgOffset }
                    if ([System.IO.Path]::GetExtension($Destination).ToLower() -eq '.msp') {
                        $bytes = [ManagementConsole.WebServices]::Packages.ContinuePatchDownload($dKey, $pkgOffset, $pkgChunk)
                    } else {
                        $bytes = $script:PKG_MGR.ContinuePackageVersionDownload($dKey, $pkgOffset, $pkgChunk)
                    }
                    $fs.Write($bytes, 0, $bytes.Length)
                    $bytes = 0
                    $pkgOffset += $pkgChunk
                } until ($pkgOffset -eq $pkgSize)
                if ($ShowProgress.IsPresent) { Write-Progress -Activity "Exporting Package" -Completed }
            }
            $ret = $true
        }
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    if ($fs) { $fs.Close() }
    return $ret
}

function Get-PkgObjectFromPackagesDataset {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        $PackagesDataSet
    )

    try {
        $ret = @()
        foreach ($p in $PackagesDataSet) {
            $props = @{}
            if ($p | Get-Member -Name PatchKey) { #MSP
                $pkg = $dsPackages.PackageVersions | Where PackageVersionKey -eq $p.PackageVersionKey
                $props.Add('PatchKey', $p.PatchKey)
                $props.Add('Version', (New-Object System.Version($p.Major, $p.Minor, $p.Build, $p.Revision)))
            } else { #MSI
                $pkg = $p
            }
            $pBase = $dsPackages.Packages | Where PackageKey -eq $pkg.PackageKey
            $props.Add('PackageKey', $pkg.PackageKey)
            $props.Add('PackageVersionKey', $pkg.PackageVersionKey)
            $props.Add('Platform', $pBase.Platform)
            $props.Add('ProductKey', $pBase.ProductKey)
            $props.Add('ProductName', $pBase.ProductName)
            $props.Add('Locked', $pBase.Locked)
            $pLockedBy = if ($pBase.LockedUserName -ne 0) { $pBase.LockedUserName } else { $null }
            $props.Add('LockedBy', $pLockedBy)
            $props.Add('Name', $pkg.Name)
            $props.Add('Type', $pBase.Type)
            $props.Add('BaseVersion', (New-Object System.Version($pkg.Major, $pkg.Minor, $pkg.Build, $pkg.Revision)))
            $ret += New-Object -TypeName PSObject -Property $props
        }
        if (-not $ret.length) { $ret = $false }
    } catch {
        $ret = $false
    }
    return $ret
}

Export-ModuleMember -Function *-Package*, Set-LogPath