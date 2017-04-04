Param([string[]]$RequiredAssemblies)

$continue = $true
$p = if ($global:AMC_WEBSRV_PATH) { $global:AMC_WEBSRV_PATH } else { "$env:ProgramFiles\AppSense\Management Center\Console" }
foreach ($a in $RequiredAssemblies) {
    $path = Join-Path -Path $p -ChildPath $a
    if (-not (Test-Path $path)) {
        Write-Warning "Not loading module as $path is not available"
        $continue = $false
    }
}
if (-not $continue) { break }
foreach ($a in $RequiredAssemblies) {
    if ($a) {
        $path = Join-Path -Path $p -ChildPath $a
        Add-Type -Path $path
    }
}