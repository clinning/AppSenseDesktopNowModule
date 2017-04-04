. $PSScriptRoot\requiredassemblies.ps1 @($AppSenseDefaults.ManagementServer.WebServicesDLL)

function Get-Product {
    # .ExternalHelp AppSenseDesktopNowAMCProducts.psm1-help.xml
    [CmdletBinding(DefaultParameterSetName='All')]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName='ByKey')]
        [string]$ProductKey,

        [Parameter(Mandatory=$true, ParameterSetName='ByName')]
        [string]$Name,

        [Parameter(Mandatory=$false)]
        [switch]$ReturnDataSet,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        $n = 0
        if (-not [ManagementConsole.WebServices]::Products) { Throw('Please ensure that you are connected to the Management Server') }
        Write-LogText "Retrieving products" -TrackTime:$TrackTime.IsPresent
        $ret = [ManagementConsole.WebServices]::Products.GetProducts()
        if (-not $ret) { Throw('No products found') }
        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            $products = $ret.Products | Where Name -eq $Name
        } elseif ($PSCmdlet.ParameterSetName -eq 'ByKey') {
            $products = $ret.Products | Where ProductKey -eq $ProductKey
        }
        if ($PSCmdlet.ParameterSetName -ne 'All') {
            if ($products) {
                $ret = New-Object ManagementConsole.ProductsWebService.ProductsDataSet
                foreach ($p in $products) { [void]$ret.Products.ImportRow($p) }
                $n = $ret.Products.Count
            } else {
                $ret = $false
                $n = 0
            }
        } else {
            $n = $ret.Products.Count
        }
        if (-not $ReturnDataSet.IsPresent) { $ret = $ret.Products }
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    $msg = "$n product"
    if ($n -ne 1) { $msg += "s" }
    $msg += " match"
    if ($n -eq 1) { $msg += "es" }
    $msg += " the specified criteria"
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

function Set-Product {
    [CmdletBinding(DefaultParameterSetName='IconString')]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$ProductKey,

        [Parameter(Mandatory=$true)]
        [string]$ProductName,

        [Parameter(Mandatory=$true, ParameterSetName='IconString')]
        [string]$IconString,

        [Parameter(Mandatory=$true, ParameterSetName='IconFile')]
        [string]$IconFile,

        [Parameter(Mandatory=$false)]
        [switch]$SupportsAgents,

        [Parameter(Mandatory=$false)]
        [switch]$SupportsConfigurations,

        [Parameter(Mandatory=$false)]
        [switch]$SupportsSoftware,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    try {
        $ret = $false
        if (-not [ManagementConsole.WebServices]::Products) { Throw('Please ensure that you are connected to the Management Server') }
        $paramsProduct = Get-MatchingCmdletParameters -Cmdlet "Get-Product" -CurrentParameters $PSBoundParameters
        $exists = Get-Product @paramsProduct
        if ($exists) {
            Write-Warning "Updating product not implemented yet"
        } else {
            if ($PSCmdlet.ParameterSetName -eq 'IconString') {
                $icoBytes = [System.Text.Encoding]::Default.GetBytes($IconString)
                $icoRes = New-Object System.IO.MemoryStream @(,$icoBytes)
            } elseif ($PSCmdlet.ParameterSetName -eq 'IconFile') {
                if (-not (Test-Path -Path $IconFile)) { Throw('Product icon file not found') }
                $icoRes = $IconFile
            }
            $ico = New-Object System.Drawing.Icon($icoRes)
            $ms = New-Object System.IO.MemoryStream
            $bf = New-Object System.Runtime.Serialization.Formatters.Binary.BinaryFormatter
            [void]$bf.Serialize($ms, $ico)
            [void]$ms.Seek(0, 0);
            $icoBytes = New-Object byte[] $ms.Length
            [void]$ms.Read($icoBytes, 0, $ms.Length)
            $ret = [ManagementConsole.WebServices]::Products.CreateProduct($ProductKey, $ProductName, $icoBytes, $SupportsAgents.IsPresent, $SupportsConfigurations.IsPresent, $SupportsSoftware.IsPresent)
            $ret = if ($ret) { $true } else { $false }
        }
    } catch {
        Write-LogText $_ -TrackTime:$TrackTime.IsPresent
        $ret = $false
    }
    $msg = if ($ret) { "Successfully" } else { "Failed to" }
    $msg += " create"
    $msg += if ($ret) { "d " } else { " " }
    $msg += $Name
    Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    return $ret
}

Export-ModuleMember -Function *-Product*, Set-LogPath