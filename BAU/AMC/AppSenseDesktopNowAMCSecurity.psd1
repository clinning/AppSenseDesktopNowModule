@{
    RootModule = 'AppSenseDesktopNowAMCSecurity'
    ModuleVersion = '2015.11.12.0'
    GUID = '84990dc9-1312-4d30-ae2a-feca775242c1'
    Author = 'James Simpson'
    CompanyName = 'uvjim'
    Copyright = '(c) 2015 James Simpson. All rights reserved.'
    Description = 'Allows management of the BAU tasks for Security methods required for the AppSense Management Server'
    PowerShellVersion = '3.0'
    CLRVersion = '4.0.30319'
    RequiredAssemblies = @("$env:ProgramFiles\AppSense\Management Center\Console\ManagementConsole.WebServices.dll")
    NestedModules = @('..\..\common\AppSenseDesktopNowCommon', '.\AppSenseDesktopNowAMCHelpers')
    DefaultCommandPrefix = 'AppSenseManagementServer'
}

