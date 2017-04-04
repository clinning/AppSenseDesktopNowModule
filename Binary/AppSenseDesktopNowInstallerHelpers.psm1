<##############################################################################################
    Aim:        Add the types necessary for the Installer CmdLets
##############################################################################################>
Add-Type -TypeDefinition @"
    namespace AppSenseDesktopNow {
        public enum Products { ManagementCenter, PersonalizationServer }
        public enum Consoles { EnvironmentManagerPolicyOnly, ManagementCenter, EnvironmentManagerPersonalizationOnly,  EnvironmentManagerPolicyAndPersonalization }
    }
"@

$MsiQueryProductStateDefinition = @"
    public enum INSTALLSTATE {
        INSTALLSTATE_NOTUSED      = -7,  // component disabled
        INSTALLSTATE_BADCONFIG    = -6,  // configuration data corrupt
        INSTALLSTATE_INCOMPLETE   = -5,  // installation suspended or in progress
        INSTALLSTATE_SOURCEABSENT = -4,  // run from source, source is unavailable
        INSTALLSTATE_MOREDATA     = -3,  // return buffer overflow
        INSTALLSTATE_INVALIDARG   = -2,  // invalid function argument
        INSTALLSTATE_UNKNOWN      = -1,  // unrecognized product or feature
        INSTALLSTATE_BROKEN       =  0,  // broken
        INSTALLSTATE_ADVERTISED   =  1,  // advertised feature
        INSTALLSTATE_REMOVED      =  1,  // component being removed (action state, not settable)
        INSTALLSTATE_ABSENT       =  2,  // uninstalled (or action state absent but clients remain)
        INSTALLSTATE_LOCAL        =  3,  // installed on local drive
        INSTALLSTATE_SOURCE       =  4,  // run from source, CD or net
        INSTALLSTATE_DEFAULT      =  5,  // use default, local or source
    }

    [DllImport("msi.dll", SetLastError=true)]
    public static extern INSTALLSTATE MsiQueryProductState(string product);

    [DllImport("msi.dll", CharSet=CharSet.Unicode)]
    public static extern Int32 MsiGetProductInfo(string product, string property, [Out] StringBuilder valueBuf, ref Int32 len);
"@
$Msi = Add-Type -MemberDefinition $MsiQueryProductStateDefinition -Name 'Msi' -Namespace 'Win32' -Using System.Text -PassThru

<##############################################################################################
    Aim:        To translate the given enum element to the tag used in the JSON config file
##############################################################################################>
function Get-Product([AppSenseDesktopNow.Products]$p) {
    $prods = @('AMC', 'EMPS')
    return $prods[$p]
}

<##############################################################################################
    Aim:        To translate the given enum element to the tag used in the JSON config file
##############################################################################################>
function Get-Console([AppSenseDesktopNow.Consoles]$c) {
    $consoles = @('EMPolicyConsole', 'MSConsole', 'EMPersonalisationConsole', 'EMConsole')
    return $consoles[$c]
}

function Test-PrerequisiteInstalled {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, HelpMessage='The prerequisite to look for')]
        [string]$PrerequisiteName = [string]::Empty,

        [Parameter(Mandatory=$true, ParameterSetName='RegistryCheck')]
        [string]$RegPath = [string]::Empty,

        [Parameter(Mandatory=$false, ParameterSetName='RegistryCheck')]
        [string]$RegValue = [string]::Empty,

        [Parameter(Mandatory=$false, ParameterSetName='RegistryCheck')]
        [string]$RegData = [string]::Empty,

        [Parameter(Mandatory=$true, ParameterSetName='RegistryCheck')]
        [ValidateSet('eq', 'ge')]
        [string]$RegCompare = 'eq',

        [Parameter(Mandatory=$true, ParameterSetName='ProductCheck')]
        [string]$ProductCode = [string]::Empty,

        [Parameter(Mandatory=$false, ParameterSetName='ProductCheck')]
        [string]$ProductProperty = [string]::Empty,

        [Parameter(Mandatory=$false, ParameterSetName='ProductCheck')]
        [string]$ProductPropertyValue = [string]::Empty,

        [Parameter(Mandatory=$false)]
        [switch]$TrackTime
    )

    Begin {
        if (Get-Command Get-CallerPreference -CommandType Function -ErrorAction SilentlyContinue) {
            Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        }
    }
    Process {
        $ret = $false
        Write-LogText "Checking if $PrerequisiteName is already installed" -TrackTime:$TrackTime.IsPresent
        switch ($PSCmdlet.ParameterSetName) {
            "RegistryCheck" { $ret = _registryCheck $RegPath $RegValue $RegData $RegCompare }
            "ProductCheck" { $ret = _productCheck -ProductCode $ProductCode $ProductProperty $ProductPropertyValue}
        }
        $msg = "$PrerequisiteName is "
        if ($ret) { $msg += "already installed" } else { $msg += "not installed" }
        Write-LogText $msg -TrackTime:$TrackTime.IsPresent
    }
    End {
        return $ret
    }
}

function _registryCheck([string]$regPath, [string]$regValue, [string]$regData, [string]$regCompare) {
    $ret = $false
    $r = Get-ItemProperty "Registry::$regPath"
    if ($r) {
        if ($regValue -ne [string]::Empty) {
            if ($r.$regValue) {
                if ($regData -ne [string]::Empty) {
                        switch ($regCompare) {
                            'eq' { if ($r.$regValue -eq $regData) { $ret = $true } }
                            'ge' { if ($r.$regValue -ge $regData) { $ret = $true } }
                        }
                    } else {
                        $ret = $true
                    }
            }
        } else {
            $ret = $true
        }
    }
    return $ret
}

function _productCheck([string]$ProductCode, [string]$Property = [string]::Empty, [string]$PropertyValue = [string]::Empty) {
    $ret = $false
    if ($Property) {
        $len = 255
        $tResult = New-Object "System.Text.StringBuilder"
        $tResult.Length = $len
        $res = [Win32.Msi]::MsiGetProductInfo($ProductCode, $Property, $tResult, [ref]$len)
        if ($res -eq 0) {
            $tResult =$tResult.toString()
            if ($tResult -eq $PropertyValue) { $ret = $true }
        }
    } else {
        $res  = [Win32.Msi]::MsiQueryProductState($ProductCode)
        $ret = $res -eq 5
    }
    return $ret
}

Export-ModuleMember -Function Get-Product
Export-ModuleMember -Function Get-Console
Export-ModuleMember -Function Test-PrerequisiteInstalled