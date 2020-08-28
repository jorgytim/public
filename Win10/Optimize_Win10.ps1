#Requires -RunAsAdministrator
<# 
.SYNOPSIS
    Cleans up Windows 10 2004 optimization
.DESCRIPTION
    
.NOTES
    Author: jorgytim
    1.0 - 2020-08-28 - Initial release

    DEPENDENCIES: 1. On the target machine, run PowerShell elevated (as administrator)
                  2. This PowerShell script
                  3. The text input files containing all the apps, services, traces, etc. that you
                     may be interested in disabling. Review these input files to customize environmental requirements

    REFERENCES:

    Optimization tasks performed by this script:
    - Appx package cleanup
#>

[Cmdletbinding()]
param(
)

#region Functions

Function Remove-AppxPackages {
    $appxPackagesInput = "$($PSScriptRoot)\win10_AppxPackagesRemove.txt"
    
    #write out that process has started
    write-host "Cleaning up provisioned Appx packages" -ForegroundColor green
    
    #testing for presence of input file
    If (Test-Path "$($appxPackagesInput)") {
        $AppxPackage = Get-Content "$($appxPackagesInput)"

        #valid packages found in input, proceed with actions
        If ($AppxPackage.Count -gt 0)
        {
            Foreach ($Item in $AppxPackage)
            {
                $Package = "*$Item*"
                Write-Host "Attempting to remove $($Item)"
                Get-AppxPackage | Where-Object {$_.PackageFullName -like $Package} | Remove-AppxPackage -ErrorAction SilentlyContinue
                
                Write-Host "`t`tAttempting to remove [All Users] $($Item)"
                Get-AppxPackage -AllUsers | Where-Object {$_.PackageFullName -like $Package} | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                
                Write-Host "`t`tRemoving Provisioned Package $($item)"
                Get-AppxProvisionedPackage -Online | Where-Object {$_.PackageName -like $Package} | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
            }
        }
    }
    else{
        write-host "$($appxpackagesInput) input file missing." -ForegroundColor red
    }
}

#endregion Functions

#region Constants

#endregion Constants

#region Main
#set running location for the script
Set-Location $PSScriptRoot

## Run optimization functions
Remove-AppxPackages

#completion output messages
write-host "Windows 10 Optimizations are complete." -ForegroundColor Green
Write-host "Remove $($psscriptRoot) from this computer" -ForegroundColor Green

#endregion Main
