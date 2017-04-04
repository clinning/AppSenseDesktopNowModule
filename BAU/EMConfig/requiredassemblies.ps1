Param([string[]]$RequiredAssemblies)

$continue = $true
$p = Get-DesktopNowDLLPath -Instance "" -Product "EM Configuration"
foreach ($a in $RequiredAssemblies) {
    $path = Join-Path -Path $p -ChildPath $a
    if (-not (Test-Path $path)) {
        Write-Warning "Not loading module as $path is not available"
        $continue = $false
    }
}
if (-not $continue) { break }
foreach ($a in $RequiredAssemblies) {
    $path = Join-Path -Path $p -ChildPath $a
    Add-Type -Path $path
}