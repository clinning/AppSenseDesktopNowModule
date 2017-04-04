@{
    RootModule = 'AppSenseDesktopNowAMCServer'
    ModuleVersion = '2016.09.08.0'
    GUID = '84d92fb2-b1e8-4360-bb9a-bfec5467e573'
    Author = 'James Simpson'
    CompanyName = 'uvjim'
    Copyright = '(c) 2015 James Simpson. All rights reserved.'
    Description = 'Allows management of the BAU tasks for Server methods required for the AppSense Management Server'
    PowerShellVersion = '3.0'
    CLRVersion = '4.0.30319'
    # RequiredAssemblies = @("$env:ProgramFiles\AppSense\Management Center\Console\ManagementConsole.WebServices.dll")
    NestedModules = @('..\..\common\AppSenseDesktopNowCommon', '.\AppSenseDesktopNowAMCCommon')
    DefaultCommandPrefix = 'AppSenseManagement'
}

