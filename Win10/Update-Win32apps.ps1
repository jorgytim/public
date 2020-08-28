#Requires -RunAsAdministrator
<# 
.SYNOPSIS
    Updates various Win32apps, if installed
.DESCRIPTION
    Mainly used in conjunction with Optimize_VDI_Win10.ps1 in order to get applications updated on a reference image.
.NOTES
    Author: tajorgen
    1.0 - 2020-07-23 - Initial release
#>

[Cmdletbinding()]
param(
    [switch]$IncludeAdobeCC
)

#region Functions

function update-windows{
    # Run windows updater
    write-host "Checking for windows updates" -ForegroundColor green
    start-process "usoclient" -ArgumentList "ScanInstallWait" -wait -NoNewWindow
    start-process "usoclient" -ArgumentList "StartInstall" -wait -NoNewWindow
}

function update-firefox{
    write-host "Checking for firefox updates" -ForegroundColor green

    # check for firefox updates if presently installed
    $firefoxInstalled = Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Where-Object {$_.DisplayName -like "*Firefox*"}
    If ($firefoxInstalled -ne $null) {
        write-host "Starting Firefox update check" -ForegroundColor yellow
        $localpath = $psscriptroot
        $baseline_url = "https://product-details.mozilla.org/1.0/firefox_versions.json"
        $getLatest = Invoke-WebRequest -Uri $baseline_url -UseBasicParsing | convertfrom-json
        $latestVer = $getlatest.latest_firefox_version
        if ($latestVer -gt $firefoxinstalled.displayversion){
            write-host "Firefox is out of date, downloading latest version and installing." -ForegroundColor yellow
            $download_url = "https://download.mozilla.org/?product=firefox-latest&os=win64&lang=en-US"
            $firefox_save_location = "$($localpath)\firefox-setup.exe"
            $download_firefox = New-Object System.Net.WebClient
            $download_firefox.DownloadFile($download_url, $firefox_save_location)
            Start-Process "$($firefox_save_location)" -ArgumentList "/s" -Wait -NoNewWindow
            remove-item $firefox_save_location
        }
    }
}

function update-onedrive{
    # run Onedrive standalone updater
    $oneDriveUpdater = "C:\Program Files (x86)\Microsoft OneDrive\OneDriveStandaloneUpdater.exe"
    if (test-path $oneDriveUpdater){
        write-host "Starting Onedrive per-machine updater" -ForegroundColor yellow
        start-process "$($oneDriveUpdater)" -Wait -NoNewWindow
    }    
}

function update-chrome{
    # run edge chromium updater
    $chromeUpdater = "C:\Program Files (x86)\Google\Update\GoogleUpdate.exe"
    $chromeArgs = "/ua /installsource scheduler"
    if (test-path $chromeUpdater){
        write-host "Starting Chrome updater" -ForegroundColor yellow
        start-process "$($chromeUpdater)" -ArgumentList "$($chromeArgs)" -Wait -NoNewWindow
    }
}

function update-edge{
    # run edge chromium updater/install
    $edgeUpdater = "C:\Program Files (x86)\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe"
    $edgeArgs = "/ua /installsource scheduler"
    
    #check if Edge updater present and run updater
    if (test-path $edgeUpdater){
        write-host "Starting Edge chromium updater" -ForegroundColor yellow
        start-process "$($edgeUpdater)" -ArgumentList "$($edgeArgs)" -Wait -NoNewWindow
    }
    else{
        #edge not installed, download and install
        [string]$Channel="Stable"
        [string]$OutFolder=$PSScriptRoot
        [string]$Platform = "Windows"
        [string]$Architecture = "x64"

        Write-host "Downloading/installing Edge Chromium browser..." -ForegroundColor green
        Write-Host "Getting available files from https://edgeupdates.microsoft.com/api/products?view=enterprise" -ForegroundColor Green
        $response = Invoke-WebRequest -Uri "https://edgeupdates.microsoft.com/api/products?view=enterprise" -Method Get -ContentType "application/json" -UseBasicParsing -ErrorAction Stop
        $jsonObj = ConvertFrom-Json $([String]::new($response.Content))
        Write-Host "Succefully retrieved Edge release data" -ForegroundColor Green

        $SelectedIndex = [array]::indexof($jsonObj.Product, "$Channel")

        Write-host "Getting the latest version for $Channel" -ForegroundColor Green
        $SelectedVersion = (([Version[]](($jsonObj[$SelectedIndex].Releases | Where-Object { $_.Architecture -eq $Architecture -and $_.Platform -eq $Platform }).ProductVersion) | Sort-Object -Descending)[0]).ToString(4)
        Write-Host "Latest Version for Chanel $Channel is $SelectedVersion" -ForegroundColor Green
        $SelectedObject = $jsonObj[$SelectedIndex].Releases | Where-Object { $_.Architecture -eq $Architecture -and $_.Platform -eq $Platform -and $_.ProductVersion -eq $SelectedVersion }

        #download file using .net.webclient, faster than invoke-webrequest
        $FileName = ($SelectedObject.Artifacts.Location -split "/")[-1]
        Write-host "Starting download of $($SelectedObject.Artifacts.Location)" -ForegroundColor Green
        #Invoke-WebRequest -Uri $SelectedObject.Artifacts.Location -OutFile "$OutFolder\$FileName" -ErrorAction Stop
        $download_url = $SelectedObject.Artifacts.Location
        $edge_save_location = "$($outFolder)\$($filename)"
        $download_edge = New-Object System.Net.WebClient
        $download_edge.DownloadFile($download_url, $edge_save_location)

        #verify downloaded file, continue with install if correct
        if (((Get-FileHash -Algorithm $SelectedObject.Artifacts.HashAlgorithm -Path "$OutFolder\$FileName").Hash) -eq $SelectedObject.Artifacts.Hash) {
            Write-Host "CheckSum OK, edge download complete and installation starting." -ForegroundColor Green
            $params = '/i', """$($outFolder)\$($filename)""", '/q'
            try {
                Start-Process 'msiexec.exe' -ArgumentList $params -NoNewWindow -Wait -PassThru
                remove-item $edge_save_location
                write-host "Edge Download/installation compelete." -ForegroundColor green
            }
            catch {   
                Write-host "Edge Installation failed."
            }
            
        }
        else {
            Write-host "Checksum mismatch!" -ForegroundColor Red
            Write-Host "Expected Hash        : $($SelectedObject.Artifacts.Hash)" -ForegroundColor Yellow
            Write-Host "Downloaded file Hash : $((Get-FileHash -Algorithm $SelectedObject.Artifacts.HashAlgorithm -Path "$OutFolder\$FileName").Hash)" -ForegroundColor Yellow
        }
    }
}

function update-office365{
    # run office365 click-to-run updater
    $office365Updater = "C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"
    $office365Args = "/update user"
    if (test-path $office365Updater){
        write-host "Starting Office365 click-to-run updater" -ForegroundColor yellow
        Start-Process "$($office365Updater)" -ArgumentList "$($office365Args)" -Wait -NoNewWindow
    }
}

function update-adobeCC{
    # update adobe creative cloud apps
    $adobeUpdater = "C:\Program Files (x86)\Common Files\Adobe\OOBE_Enterprise\RemoteUpdateManager\remoteupdatemanager.exe"
    if (test-path $adobeUpdater){
        write-host "Starting Creative Cloud updater...this may take a while." -ForegroundColor yellow
        start-process "$($adobeUpdater)" -wait -NoNewWindow
    }
}

#endregion functions

#region main
update-windows
update-firefox
update-onedrive
update-chrome
update-edge
update-office365

#if the includeadobecc switch is provided at runtime
if ($IncludeAdobeCC){
    update-adobeCC
}


#endregion main