@{
    RootModule = 'AppSenseDesktopNowAMCLicenses'
    ModuleVersion = '2016.09.08.0'
    GUID = '61029603-1937-4a36-8b86-24c2d1d90b92'
    Author = 'James Simpson'
    CompanyName = 'uvjim'
    Copyright = '(c) 2015 James Simpson. All rights reserved.'
    Description = ''
    PowerShellVersion = '3.0'
    CLRVersion = '4.0.30319'
    # RequiredAssemblies = @("$env:ProgramFiles\AppSense\Management Center\Console\ManagementConsole.WebServices.dll", "$env:ProgramFiles\AppSense\Management Center\Console\Licensing.dll")
    NestedModules = @('..\..\common\AppSenseDesktopNowCommon', '.\AppSenseDesktopNowAMCCommon', '.\AppSenseDesktopNowAMCHelpers')
    DefaultCommandPrefix = 'AppSenseManagementServer'
}

