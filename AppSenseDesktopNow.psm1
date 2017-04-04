$dllWebServices = "ManagementConsole.WebServices.dll"
$pathWebServices = if ($global:AMC_WEBSRV_PATH) { $global:AMC_WEBSRV_PATH } else { "$env:ProgramFiles\AppSense\Management Center\Console" }
$pathWebServices = Join-Path -Path $pathWebServices -ChildPath $dllWebServices
if (Test-Path $pathWebServices) {
    Import-Module "$PSScriptRoot\BAU\AMC\AppSenseDesktopNowAMC" -Scope Global
} else {
    Write-Warning "Skipping loading the AppSenseDesktopNowAMC module as $pathWebServices is not found"
}