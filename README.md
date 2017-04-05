## Requirements
The module requires PowerShell version 3 at a mimimum which should also include any other pre-requisite that the module has.
It also works with versions later than that so not to worry if PowerShell 4 or 5 is already in your estate.

Depending on the nature of usage you may also need to be running the commands on a machine that either has the relevant AppSense agent or AppSense console installed.

The documentation for the APIs in use can be found in the download of the software - typically in the Guides folder.

## What's included
A release file includes the following: -

* Example scripts for usage
* Functionality for installing AppSense software on a vanilla server install
  * Single server deployment
  * Named instances
  * INstallation from a remote server
* Functionality for configuring the SCU/SCP for AppSense Management Center (AMC) and Environment Manager Personalization Server (EMPS)
* Functionality for BAU tasks including: -
  * AMC
  * EMPS
  * Environment Manager (EM) Configurations

## Getting Help
Help the cmdlets can be obtained using standard PowerShell practice.

```Get-Help <cmdlet_name>```

Help was created using https://pscmdlethelpeditor.codeplex.com/

## Notes
Some basic AMC, EMPS and EM Config API functions have been prettified into cmdlets.

If there isn't a pretty cmdlet for something that you need then you should be able to use the ```Invoke-*Native*``` cmdlet in that module to carry out the direct API call.
If you find yourself doing this, please raise that here, along with the use case, and we'll endeavour to prettify this into a cmdlet.
