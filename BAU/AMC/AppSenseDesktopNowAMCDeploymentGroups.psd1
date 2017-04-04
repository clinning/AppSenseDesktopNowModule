@{
    RootModule = 'AppSenseDesktopNowAMCDeploymentGroups'
    ModuleVersion = '2016.09.08.0'
    GUID = 'f0f3d68f-a941-4bfd-baf5-5b0038c17a88'
    Author = 'James Simpson'
    CompanyName = 'uvjim'
    Copyright = '(c) 2015 James Simpson. All rights reserved.'
    Description = ''
    PowerShellVersion = '3.0'
    CLRVersion = '4.0.30319'
    # RequiredAssemblies = @("$env:ProgramFiles\AppSense\Management Center\Console\ManagementConsole.WebServices.dll")
    NestedModules = @('..\..\common\AppSenseDesktopNowCommon', '.\AppSenseDesktopNowAMCCommon')
    DefaultCommandPrefix = 'AppSenseManagementServer'
}
