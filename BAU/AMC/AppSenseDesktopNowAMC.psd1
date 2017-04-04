@{
    RootModule = ''
    ModuleVersion = '2016.08.05.0'
    GUID = 'b827767d-6281-4dc2-ab06-f39d1096e945'
    Author = 'James Simpson'
    CompanyName = 'uvjim'
    Copyright = '(c) 2015 James Simpson. All rights reserved.'
    Description = 'Meta module for the BAU tasks required for the AppSense Management Server'
    PowerShellVersion = '3.0'
    CLRVersion = '4.0.30319'
    NestedModules = @('.\AppSenseDesktopNowAMCServer',
                      '.\AppSenseDesktopNowAMCSecurity',
                      '.\AppSenseDesktopNowAMCLicenses',
                      '.\AppSenseDesktopNowAMCProducts',
                      '.\AppSenseDesktopNowAMCPackages',
                      '.\AppSenseDesktopNowAMCPrereqs',
                      '.\AppSenseDesktopNowAMCDeploymentGroups'
                    )
}

