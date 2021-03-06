@{
    RootModule = 'AppSenseDesktopNowInstaller'
    ModuleVersion = '2016.08.10.0'
    GUID = '96bba441-1e7a-4e18-ba11-a935edd6ab87'
    Author = 'James Simpson'
    CompanyName = 'uvjim'
    Copyright = '(c) 2015 James Simpson. All rights reserved.'
    Description = 'A module that allows installation of the server components, and the pre-requisites, of the AppSense DesktopNow suite.'
    PowerShellVersion = '3.0'
    CLRVersion = '4.0.30319'
    NestedModules = @('../common/AppSenseDesktopNowCommon', 'AppSenseDesktopNowConfigReader', 'AppSenseDesktopNowInstallerHelpers', '../BinaryAncillary/AppSenseDesktopNowBinaryAncillary')
    DefaultCommandPrefix = 'AppSenseDesktopNow'
}

