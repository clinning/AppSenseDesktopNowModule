@{
    RootModule = 'AppSenseDesktopNowAMCPrereqs'
    ModuleVersion = '2016.04.18.0'
    GUID = '1e4e563a-814b-4307-a357-31770e50191b'
    Author = 'James Simpson'
    CompanyName = 'uvjim'
    Copyright = '(c) 2015 James Simpson. All rights reserved.'
    Description = ''
    PowerShellVersion = '3.0'
    CLRVersion = '4.0.30319'
    # RequiredAssemblies = @("$env:ProgramFiles\AppSense\Management Center\Console\ManagementConsole.WebServices.dll")
    NestedModules = @('..\..\common\AppSenseDesktopNowCommon', '.\AppSenseDesktopNowAMCHelpers')
    DefaultCommandPrefix = 'AppSenseManagementServer'
}

