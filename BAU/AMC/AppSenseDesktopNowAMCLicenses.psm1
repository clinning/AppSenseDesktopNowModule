. $PSScriptRoot\requiredassemblies.ps1 @($AppSenseDefaults.ManagementServer.WebServicesDLL, $AppSenseDefaults.ManagementServer.LicensingDLL)

function Get-License {
    # .ExternalHelp AppSenseDesktopNowAMCLicenses.psm1-help.xml
    [CmdletBinding(DefaultParameterSetName='All')]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName='ByCode')]
        [string]$LicenseCode,

        [Parameter(Mandatory=$true, ParameterSetName='ExpireInDays')]
        [int]$ExpireInDays,

        [Parameter(Mandatory=$true, ParameterSetName='AllExpired')]
        [switch]$ExpiredOnly,

        [Parameter(Mandatory=$false)]
        [switch]$ReturnDataSet,

        [Parameter(Mandatory=$false)]
        [switch]$V1Licenses,

        [Parameter(Mandatory=$false)]
        [switch]$V2Licenses,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        $lic = $false
        $dtMin = [DateTime]"1/1/1970 00:00:00"
        if (-not [ManagementConsole.WebServices]::Licenses) { Throw('Please ensure that you are connected to the Management Server') }
        if (-not $V1Licenses -and -not $V2Licenses) {
            $prefix = Get-ModuleDetails -Path "$PSScriptRoot\AppSenseDesktopNowAMCLicenses" -Property 'Prefix' -TrackTime:$TrackTime.IsPresent -Verbose:$false
            $cmdlet = "Get-{0}Version" -f $prefix
            $ver = & $cmdlet
            if (-not $ver) { Throw('Unable to determine server version') }
            $ver = [System.Version]$ver
            if ($ver.Major -lt 10) { $V1Licenses = $true }
            if ($ver.Major -ge 10) { $V2Licenses = $true }
        }
        #-- look for the v1 licenses first --#
        if ($V1Licenses) {
            Write-LogText "Retrieving v1 licenses" -TrackTime:$TrackTime.IsPresent
            $retV1 = [ManagementConsole.WebServices]::Licenses.GetLicenses()
            if ($PSCmdlet.ParameterSetName -eq 'ByCode') {
                Write-LogText "Filtering v1 licenses for $LicenseCode" -TrackTime:$TrackTime.IsPresent
                $lic = $retV1.Licenses | Where LicenseCode -eq $LicenseCode
                if ($lic) {
                    $retV1 = New-Object ManagementConsole.LicensesWebService.LicensesDataSet
                    foreach ($l in $lic) { [void]$ret.Licenses.ImportRow($l) }
                } else {
                    $retV1 = $false
                }
            }
            if ($retV1) {
                foreach ($rowLic in $retV1.Licenses) {
                    $lic = New-Object Licensing.LicensingCore($rowLic.LicenseCode)
                    $rowLic.ExpiryDate = $lic.GetExpiryDate()
                    $rowLic.BaseLicense = $lic.IsBaseLicence()
                    $rowLic.LicenseCount = $lic.GetLicenceCount()
                }
                if ($ExpiredOnly.IsPresent) {
                    $dtNow = [DateTime]::Now
                    Write-LogText "Filtering for expired v1 licenses" -TrackTime:$TrackTime.IsPresent
                    $lic = $retV1.Licenses | Where ExpiryDate -lt $dtNow
                    $lic = $lic | Where ExpiryDate -ne $dtMin
                    if ($lic) {
                        $retV1 = New-Object ManagementConsole.LicensesWebService.LicensesDataSet
                        foreach ($l in $lic) { [void]$retV1.Licenses.ImportRow($l) }
                    } else {
                        $retV1 = $false
                    }
                }
                if ($ExpireInDays) {
                    $dtExpire = (Get-Date).AddDays($ExpireInDays)
                    $msg = "Filtering for v1 licenses that will expire within $ExpireInDays day"
                    if ($ExpireInDays -ne 1) { $msg += "s" }
                    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
                    $lic = $retV1.Licenses | Where ExpiryDate -lt $dtExpire
                    $lic = $lic | Where ExpiryDate -ne $dtMin
                    if ($lic) {
                        $retV1 = New-Object ManagementConsole.LicensesWebService.LicensesDataSet
                        foreach ($l in $lic) { [void]$retV1.Licenses.ImportRow($l) }
                    } else {
                        $retV1 = $false
                    }
                }
            }
        }
        if ($V2Licenses) {
            Write-LogText "Retrieving v2 licenses" -TrackTime:$TrackTime.IsPresent
            $retV2 = [ManagementConsole.WebServices]::Licenses.GetV2Licenses()
            if ($PSCmdlet.ParameterSetName -eq 'ByCode') {
                Write-LogText "Filtering v2 licenses for $LicenseCode" -TrackTime:$TrackTime.IsPresent
                $lic = $retV2.LicensingV2 | Where LicenseKey -eq $LicenseCode
                if ($lic) {
                    $retV2 = New-Object ManagementConsole.LicensesWebService.LicensingV2DataSet
                    foreach ($l in $lic) { [void]$retV2.LicensingV2.ImportRow($l) }
                } else {
                    $retV2 = $false
                }
            }
            if ($retV2) {
                if ($ExpiredOnly.IsPresent) {
                    $dtNow = [DateTime]::Now
                    Write-LogText "Filtering for expired v2 licenses" -TrackTime:$TrackTime.IsPresent
                    $lic = $retV2.LicensingV2 | Where ExpiryDate -lt $dtNow
                    $lic = $lic | Where ExpiryDate -ne $dtMin
                    if ($lic) {
                        $retV2 = New-Object ManagementConsole.LicensesWebService.LicensingV2DataSet
                        foreach ($l in $lic) { [void]$retV2.LicensingV2.ImportRow($l) }
                    } else {
                        $retV2 = $false
                    }
                }
                if ($ExpireInDays) {
                    $dtExpire = (Get-Date).AddDays($ExpireInDays)
                    $msg = "Filtering for v2 licenses that will expire within $ExpireInDays day"
                    if ($ExpireInDays -ne 1) { $msg += "s" }
                    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
                    $lic = $retV2.LicensingV2 | Where ExpiryDate -lt $dtExpire
                    $lic = $lic | Where ExpiryDate -ne $dtMin
                    if ($lic) {
                        $retV2 = New-Object ManagementConsole.LicensesWebService.LicensingV2DataSet
                        foreach ($l in $lic) { [void]$retV2.LicensingV2.ImportRow($l) }
                    } else {
                        $retV2 = $false
                    }
                }
            }
        }
        $n = 0
        if ($V1Licenses -and -not $V2Licenses) {
            if (-not $ReturnDataSet.IsPresent) {
                $ret = $retV1.Licenses
                $n = $ret.Count
            } else {
                $ret = $retV1
                $n = $retV1.Licenses.Count
            }
        }
        if ($V2Licenses -and -not $V1Licenses) {
            if (-not $ReturnDataSet.IsPresent) {
                $ret = $retV2.LicensingV2
                $n = $ret.Count
            } else {
                $ret = $retV2
                $n = $retV2.LicensingV2.Count
            }
        }
        #-- we want both license types --#
        if ($V1Licenses -and $V2Licenses) {
            $n = $retV1.Licenses.Count + $retV2.LicensingV2.Count
            if (-not $ReturnDataSet.IsPresent) {
                $ret = New-Object PSObject -Property @{'V1Licenses'=$retV1.Licenses; 'V2Licenses'=$retV2.LicensingV2 }
            } else {
                $ret = New-Object PSObject -Property @{'V1Licenses'=$retV1; 'V2Licenses'=$retV2 }
            }
        }
        if (-not $ret) { $ret = $false }
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    $msg = "$n license"
    if ($n -ne 1) { $msg += "s" }
    $msg += " match"
    if ($n -eq 1) { $msg += "es" }
    $msg += " the specified criteria"
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

function Set-License {
    # .ExternalHelp AppSenseDesktopNowAMCLicenses.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$LicenseCode,

        [Parameter(Mandatory=$false)]
        [string]$ActivationCode,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        if (-not [ManagementConsole.WebServices]::Licenses) { Throw('Please ensure that you are connected to the Management Server') }
        $paramsLic = Get-MatchingCmdletParameters -Cmdlet 'Get-License' -CurrentParameters $PSBoundParameters
        $paramsLic.Add('ReturnDataSet', $true)
        $exists = Get-License @paramsLic
        if ($exists) {
            Write-LogText "Updating license $LicenseCode" -TrackTime:$TrackTime.IsPresent
            $licKey = ($exists.Licenses | Select -First 1).LicenseKey
            $rowLic = $exists.Licenses.FindByLicenseKey($licKey)
            if ($ActivationCode) {
                if ($ActivationCode -ne $rowLic.ActivationCode) { $rowLic.ActivationCode = $ActivationCode }
            }
            $dsLic = $exists
        } else {
            Write-LogText "Creating license $LicenseCode" -TrackTime:$TrackTime.IsPresent
            $lic = New-Object Licensing.LicensingCore($LicenseCode)
            if ($lic.GetLicenceType() -eq [Licensing.licenceType]::eInvalidLicenceType) { Throw('Invalid license code specified') }
            $dsLic = New-Object ManagementConsole.LicensesWebService.LicensesDataSet
            $rowLic = $dsLic.Licenses.NewLicensesRow()
            if ($rowLic) {
                $guid = [guid]::NewGuid()
                $rowLic.LicenseKey = $guid
                $rowLic.LicenseCode = $LicenseCode
                if ($ActivationCode) { $rowLic.ActivationCode = $ActivationCode }
            }
            $dsLic.Licenses.Rows.Add($rowLic)
        }
        [ManagementConsole.WebServices]::Licenses.ApplyChanges([ref]$dsLic)
        $ret = if ($guid) { $guid.ToString() } else { $true }
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    $msg = if ($ret) { "Successfully " } else { "Failed to " }
    $msg += if ($guid) { "create" } else { "update" }
    $msg += if ($ret) { "d" } else { "" }
    $msg += " license $LicenseCode"
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

function Remove-License {
    # .ExternalHelp AppSenseDesktopNowAMCLicenses.psm1-help.xml
    [CmdletBinding(DefaultParameterSetName='ByCode', SupportsShouldProcess=$true)]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName='ByCode')]
        [string]$LicenseCode,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        if (-not [ManagementConsole.WebServices]::Licenses) { Throw('Please ensure that you are connected to the Management Server') }
        Write-LogText "Deleting license $LicenseCode" -TrackTime:$TrackTime.IsPresent
        $paramsLic = Get-MatchingCmdletParameters -Cmdlet 'Get-License' -CurrentParameters $PSBoundParameters
        $lic = Get-License @paramsLic
        if ($lic) {
            if ($PSCmdlet.ShouldProcess($lic.LicenseCode, "Delete license")) {
                [void][ManagementConsole.WebServices]::Licenses.DeleteLicense($lic.LicenseKey, (ConvertFrom-TimeToLocal $lic.ModifiedTime))
                $ret = $true
            }
        }
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    if ($WhatIfPreference.IsPresent) { $ret = $true }
    $msg = if ($ret) { "Successfully deleted" } else { "Failed to delete" }
    $msg += " license $LicenseCode"
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

Export-ModuleMember -Function *-License*, Set-LogPath