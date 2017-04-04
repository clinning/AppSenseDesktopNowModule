@{
    RootModule = 'AppSenseDesktopNowAMCPackages'
    ModuleVersion = '2016.04.19.0'
    GUID = 'bf2bf5dd-a63f-40c1-adc7-02f4b90f5bdd'
    Author = 'James Simpson'
    CompanyName = 'uvjim'
    Copyright = '(c) 2015 James Simpson. All rights reserved.'
    Description = ''
    PowerShellVersion = '3.0'
    CLRVersion = '4.0.30319'
    # RequiredAssemblies = @("$env:ProgramFiles\AppSense\Management Center\Console\ManagementConsole.WebServices.dll")
    NestedModules = @('..\..\common\AppSenseDesktopNowCommon', '.\AppSenseDesktopNowAMCHelpers', '.\AppSenseDesktopNowAMCPrereqs')
    DefaultCommandPrefix = 'AppSenseManagementServer'
}

