. $PSScriptRoot\requiredassemblies.ps1 @($AppSenseDefaults.ManagementServer.WebServicesDLL)

function Get-Prerequisite {
    # .ExternalHelp AppSenseDesktopNowAMCPrereqs.psm1-help.xml
    [CmdletBinding(DefaultParameterSetName='All')]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName='ByKey')]
        [string]$ResourceKey,

        [Parameter(Mandatory=$true, ParameterSetName='ByPackageVersion')]
        [string]$PackageVersionKey,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        Write-LogText "Retrieving prerequisite resources" -TrackTime:$TrackTime.IsPresent
        $ret = $false
        if ($PSCmdlet.ParameterSetName -eq 'ByKey') {
            $ret = [ManagementConsole.WebServices]::Packages.GetPrerequisiteFromPrerequisiteKey($ResourceKey)
        } elseif ($PSCmdlet.ParameterSetName -eq 'ByPackageVersion') {
            $ret = [ManagementConsole.WebServices]::Packages.GetPrerequisitesForPackageVersionKey($PackageVersionKey)
        } else {
            $ret = [ManagementConsole.WebServices]::Packages.GetPrerequisites()
        }
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    $n = if ($ret) { $ret.Prerequisites.Count } else { 0 }
    if ($n -eq 0) { $ret = $false }
    $msg = "$n matching prerequisite resource"
    if ($n -ne 1) { $msg += "s" }
    $msg += if ($n -eq 1) { " was" } else { " were" }
    $msg += " found"
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

function Import-Prerequisite {
    # .ExternalHelp AppSenseDesktopNowAMCPrereqs.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$false)]
        [string]$PackageVersionKey,

        [Parameter(Mandatory=$true)]
        [ManagementConsole.PackagesWebService.PrerequisitesDataSet]$Prerequisites,

        [Parameter(Mandatory=$false)]
        [int]$ChunkSizeBytes = $AppSenseDefaults.Packages.ChunkSize,

        [Parameter(Mandatory=$false)]
        [switch]$ShowProgress,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Begin {
        $ret = $false
        if (Get-Command Get-CallerPreference -CommandType Function -ErrorAction SilentlyContinue) {
            Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        }
    }
    Process {
        try {
            $ret = Set-Prereq -Prerequisites $Prerequisites -TrackTime:$TrackTime.IsPresent
            if ($ret) {
                $Prerequisites = $ret
                $failed = @()
                foreach ($p in $Prerequisites.Prerequisites) {
                    $res = $Prerequisites.PrerequisiteResource | Where PrerequisiteKey -eq $p.PrerequisitesKey
                    if ($res) {
                        if (-not $res.Valid -and $res.DataLength -eq 0) {
                            Write-LogText "Importing $($p.Name)" -TrackTime:$TrackTime.IsPresent
                            $cmd = $Prerequisites.PrerequisiteCommand | Where PrerequisiteKey -eq $p.PrerequisitesKey
                            $pPath = Join-Path -Path $Path -ChildPath $cmd.Path
                            if (-not (Test-Path $pPath)) {
                                $failed += $p.Name
                            } else {
                                Write-LogText "Uploading $($p.Name)" -TrackTime:$TrackTime.IsPresent
                                $fSize = ([System.IO.FileInfo] $pPath).Length
                                $resModTime = $res.ModifiedTime
                                $keyUpload = [ManagementConsole.WebServices]::Packages.BeginPrerequisiteResourceUpload($res.ResourceKey, $fSize, [ref]$resModTime)
                                $fUpload = [System.IO.File]::OpenRead($pPath)
                                $bytesUploaded = 0
                                if ($ShowProgress.IsPresent) { Write-Progress -Activity "Uploading Prerequisite" -Status $p.Name -PercentComplete (($bytesUploaded / $fSize) * 100) }
                                do {
                                    if ($ChunkSizeBytes -gt ($fSize - $bytesUploaded)) { $bytesToRead = $fSize - $bytesUploaded } else { $bytesToRead = $ChunkSizeBytes }
                                    if ($bytesToRead -ne 0) {
                                        $resBuffer = New-Object byte[] $bytesToRead
                                        $resModTime = ConvertFrom-TimeToLocal $resModTime
                                        $bytesRead = $fUpload.Read($resBuffer, 0, $bytesToRead)
                                        if ($bytesRead -ne 0) {
                                            [ManagementConsole.WebServices]::Packages.ContinuePrerequisiteResourceUpload($res.ResourceKey, [ref]$resModTime, $keyUpload, $bytesUploaded, $resBuffer)
                                            $bytesUploaded += $bytesRead
                                        }
                                    }
                                } until ($bytesRead -eq 0 -or $bytesToRead -eq 0)
                                if ($ShowProgress.IsPresent) { Write-Progress -Activity "Uploading Prerequisite" -Completed }
                                Write-LogText "Successfully uploaded $($p.Name)" -TrackTime:$TrackTime.IsPresent
                                $fUpload.Close()
                            }
                        }
                    } else {
                        $failed += $p.Name
                    }
                }
                if ($failed.Count) { Throw("Failed to import $($failed -join ', ')") }
                #-- associate pre-reqs to package version --#
                if ($PackageVersionKey) {
                    Write-LogText "Associating prerequisites with the given package" -TrackTime:$TrackTime.IsPresent
                    foreach($p in $Prerequisites.Prerequisites) { [void]$Prerequisites.PackageVersionPrerequisites.AddPackageVersionPrerequisitesRow($PackageVersionKey, $p) }
                    $ret = Set-Prereq -Prerequisites $Prerequisites -TrackTime:$TrackTime.IsPresent -Verbose:$false
                    if (-not $ret) { Throw('Unable to associate prerequisites to the given package') }
                    Write-LogText "Successfully associated prerequisites with the given package" -TrackTime:$TrackTime.IsPresent
                }
                $ret = $true
            }
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        $msg = if ($ret) { "Successfully imported " } else { "Failed to import " }
        $msg += "prerequisites"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

function Export-Prerequisite {
    # .ExternalHelp AppSenseDesktopNowAMCPrereqs.psm1-help.xml
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$PackageVersionKey,

        [Parameter(Mandatory=$true)]
        [string]$DestinationFolder,

        [Parameter(Mandatory=$false)]
        [int]$ChunkSizeBytes = $AppSenseDefaults.Packages.ChunkSize,

        [Parameter(Mandatory=$false)]
        [switch]$ShowProgress,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Begin {
        $ret = $false
        if (Get-Command Get-CallerPreference -CommandType Function -ErrorAction SilentlyContinue) {
            Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        }
    }
    Process {
        try {
            $ret = $false
            $params = @{} + $PSBoundParameters
            $params = Get-MatchingCmdletParameters -Cmdlet 'Get-Prerequisite' -CurrentParameters $params
            $prereqs = Get-Prerequisite @params
            if ($prereqs) {
                foreach ($p in $prereqs) {
                    if ($p.PrerequisiteResource) {
                        foreach ($r in $p.PrerequisiteResource) {
                            $prereqName = ($prereqs.Prerequisites | Where PrerequisitesKey -eq $r.PrerequisiteKey).Name
                            $prereqOffset = 0
                            $dest = "{0}\{1}" -f $DestinationFolder, $r.Destination
                            if (-not (Test-Path -Path $dest)) {
                                Write-LogText "Exporting $prereqName to $DestinationFolder" -TrackTime:$TrackTime.IsPresent
                                $dKey = [ManagementConsole.WebServices]::Packages.BeginPrerequisiteResourceDownload($r.ResourceKey)
                                $prereqChunk = $ChunkSizeBytes
                                $fs = New-Object System.IO.FileStream($dest, 'Create', 'Write')
                                do {
                                    if ($ShowProgress.IsPresent) { Write-Progress -Activity "Exporting Prerequisite" -Status $prereqName -PercentComplete (($prereqOffset / $r.DataLength) * 100) }
                                    $prereqLeft = $r.DataLength - $prereqOffset
                                    $prereqChunk = if ($prereqLeft -ge $prereqChunk) { $prereqChunk } else { $r.DataLength - $prereqOffset }
                                    $bytes = [ManagementConsole.WebServices]::Packages.ContinuePrerequisiteResourceDownload($dKey, $prereqOffset, $prereqChunk)
                                    $fs.Write($bytes, 0, $bytes.Length)
                                    $bytes = 0
                                    $prereqOffset += $prereqChunk
                                } until ($prereqOffset -eq $r.DataLength)
                                if ($fs) { $fs.Close() }
                            } else {
                                Write-LogText "$dest already exists - skipping" -TrackTime:$TrackTime.IsPresent
                            }
                        }
                    }
                }
                $ret = $true
            }
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        if ($fs) { $fs.Close() }
        return $ret
    }
}

function Set-Prereq {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ManagementConsole.PackagesWebService.PrerequisitesDataSet]$Prerequisites,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Begin {
        $ret = $false
        # if (Get-Command Get-CallerPreference -CommandType Function -ErrorAction SilentlyContinue) {
        #     Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        # }
    }
    Process {
        try {
            Write-LogText "Updating prerequisites" -TrackTime:$TrackTime.IsPresent
            [ManagementConsole.WebServices]::Packages.ApplyPrerequisiteChanges([ref]$Prerequisites)
            $ret = $Prerequisites
        } catch {
            Write-LogText $_ -TrackTime:$TrackTime.IsPresent
            $ret = $false
        }
    }
    End {
        $msg = if ($ret) { "Successfully updated " } else { "Failed to update " }
        $msg += "prerequisites"
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
        return $ret
    }
}

Export-ModuleMember -Function *-Prerequisite*, Set-LogPath