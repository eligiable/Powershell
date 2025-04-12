<#
.SYNOPSIS
    Automated software installation script for Windows workstations.
.DESCRIPTION
    This script copies Office Deployment Toolkit (ODT) from a network share,
    installs Office 365, and downloads/installs additional software packages.
.NOTES
    File Name      : Software-Installation.ps1
    Author         : Your Name
    Prerequisite   : PowerShell 5.1 or later, Admin privileges
#>

#region Initialization
param (
    [Parameter(Mandatory=$false)]
    [string]$Source = 'C:\Softwares-for-installation',
    
    [Parameter(Mandatory=$false)]
    [string]$TargetPath = 'C:\Softwares-for-installation',
    
    [Parameter(Mandatory=$false)]
    [string]$ODTPath = "\\172.31.2.20\Backup\SoftPile\WindowsSoftware\Microsoft\Office\ODT"
)

# Clear screen and set error handling
Clear-Host
$ErrorActionPreference = "Stop"

# Create transcript log
$logPath = Join-Path -Path $Source -ChildPath "InstallationLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
Start-Transcript -Path $logPath -Append

# Get credentials once at the start
$Credentials = Get-Credential -Message "Enter your network credentials to access shared resources"

# Initialize variables
$OfficeInstallationCommand = "$Source\ODT\setup.exe /configure $Source\ODT\installOfficeBusRet64.xml"
$7zipRenamePath = Join-Path -Path $Source -ChildPath "7zip.exe"
#endregion

#region Functions
function CopyFilesfromSourcefolder {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$SourcePath,
        
        [Parameter(Mandatory=$true)]
        [string]$DestinationPath,
        
        [Parameter(Mandatory=$true)]
        [pscredential]$Credential
    )
    
    try {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Creating PsDrive from ServerPath" -ForegroundColor Cyan
        $psDrive = New-PSDrive -Name PsDrive -PSProvider "FileSystem" -Root $SourcePath -Credential $Credential -ErrorAction Stop
        
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Connection Successful! Copying files..." -ForegroundColor Green
        
        # Create destination folder if it doesn't exist
        if (-not (Test-Path -Path $DestinationPath -PathType Container)) {
            New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
        }
        
        # Copy files with progress
        $copyParams = @{
            Path        = "$SourcePath\*"
            Destination = $DestinationPath
            Recurse     = $true
            Force       = $true
            Verbose     = $true
            ErrorAction = 'Stop'
        }
        
        $totalItems = (Get-ChildItem -Path $SourcePath -Recurse -File).Count
        $currentItem = 0
        
        Get-ChildItem -Path $SourcePath -Recurse -File | ForEach-Object {
            $currentItem++
            $percentComplete = ($currentItem / $totalItems) * 100
            Write-Progress -Activity "Copying files from $SourcePath" -Status "$currentItem of $totalItems" -PercentComplete $percentComplete -CurrentOperation $_.Name
            
            Copy-Item -Path $_.FullName -Destination (Join-Path -Path $DestinationPath -ChildPath $_.Name) -Force
        }
        
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Files copied successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ERROR: $_" -ForegroundColor Red
        throw
    }
    finally {
        if ($psDrive) {
            Remove-PSDrive -Name PsDrive -Force -ErrorAction SilentlyContinue
        }
    }
}

function Install-Office {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$InstallCommand
    )
    
    try {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Installing Office 365..." -ForegroundColor Cyan
        
        if (-not (Test-Path -Path (Split-Path -Path $InstallCommand -Parent))) {
            throw "ODT files not found at expected location"
        }
        
        # Run installation as a job with timeout
        $job = Start-Job -ScriptBlock {
            param($cmd)
            Start-Process -FilePath (Split-Path -Path $cmd -Leaf) -ArgumentList (Split-Path -Path $cmd -NoQualifier) -Wait -NoNewWindow
        } -ArgumentList $InstallCommand
        
        # Wait for job with timeout (30 minutes)
        $job | Wait-Job -Timeout 1800 | Out-Null
        
        if ($job.State -eq 'Running') {
            $job | Stop-Job -Force
            throw "Office installation timed out after 30 minutes"
        }
        
        $jobResult = $job | Receive-Job
        if ($jobResult -or $job.Error) {
            throw "Office installation failed: $($job.Error)"
        }
        
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Office 365 installed successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ERROR: $_" -ForegroundColor Red
        throw
    }
    finally {
        if ($job) { $job | Remove-Job -Force }
    }
}

function Download-And-Install-Software {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$SourcePath,
        
        [Parameter(Mandatory=$true)]
        [int]$UserFloor
    )
    
    try {
        # Create software directory if it doesn't exist
        if (-not (Test-Path -Path $SourcePath -PathType Container)) {
            New-Item -Path $SourcePath -ItemType Directory -Force | Out-Null
        }
        
        # Define base packages
        $packages = @(
            @{title='Mozilla-Latest';url='https://download-installer.cdn.mozilla.net/pub/firefox/releases/69.0.3/win64/en-US/Firefox%20Setup%2069.0.3.exe';Arguments='/S';Destination=$SourcePath},
            @{title='VLC-3.0.8';url='https://get.videolan.org/vlc/3.0.8/win32/vlc-3.0.8-win32.exe';Arguments='/S';Destination=$SourcePath},
            @{title='CC-Cleaner-5.6.2';url='https://download.ccleaner.com/ccsetup562.exe';Arguments='/S';Destination=$SourcePath},
            @{title='Google FileStream';url='https://dl.google.com/drive-file-stream/GoogleDriveFSSetup.exe';Arguments='--silent';Destination=$SourcePath},
            @{title='Google App Sync';url='https://dl.google.com/tag/s/appguid%3D%7BBEBCAD10-F1BC-4F92-B4A7-9E2545C809ED%7D%26iid%3D%7B1A46AC68-444C-DCE0-84CA-E62E9E982C56%7D%26lang%3Den%26browser%3D4%26usagestats%3D0%26appname%3DG%2520Suite%2520Sync%25E2%2584%25A2%2520for%2520Microsoft%2520Outlook%25C2%25AE%26needsadmin%3Dtrue%26appguid%3D%7B7DF3B6EE-9890-4307-BDE5-E1F3FCB09771%7D%26appname%3DG%2520Suite%2520Migration%25E2%2584%25A2%2520for%2520Microsoft%2520Outlook%25C2%25AE%26needsadmin%3Dtrue/google-apps-sync/googleappssyncsetup.exe';Arguments='/quiet';Destination=$SourcePath},
            @{title='RingCentral-Glip';url='http://downloads.ringcentral.com/glip/rc/19.10.2/x64/RingCentral-19.10.2-x64.exe';Arguments='/S';Destination=$SourcePath},
            @{title='Chrome';url='https://dl.google.com/tag/s/appguid%3D%7B8A69D345-D564-463C-AFF1-A69D9E530F96%7D%26iid%3D%7B76DCB9A5-930D-6451-2DA8-E3B9C79E4218%7D%26lang%3Den%26browser%3D4%26usagestats%3D1%26appname%3DGoogle%2520Chrome%26needsadmin%3Dprefers%26ap%3Dx64-stable-statsdef_1%26installdataindex%3Ddefaultbrowser/update2/installers/ChromeSetup.exe';Arguments='/silent /install';Destination=$SourcePath},
            @{title='7zip';url='https://sourceforge.net/projects/sevenzip/files/7-Zip/19.00/7z1900-x64.exe/download';Arguments='/S';Destination=$SourcePath},
            @{title='Owncloud';url='https://download.owncloud.com/desktop/stable/ownCloud-2.5.0.10359-setup.exe';Arguments='/S';Destination=$SourcePath},
            @{title='Anydesk';url='https://download.anydesk.com/AnyDesk.exe';Arguments='--install --silent';Destination=$SourcePath},
            @{title='Foxit Reader';url='http://cdn01.foxitsoftware.com/pub/foxit/reader/desktop/win/9.x/9.7/en_us/FoxitReader97_Setup_Prom_IS.exe';Arguments='/quiet /norestart';Destination=$SourcePath}
        )
        
        # Add floor-specific packages
        switch ($UserFloor) {
            0 { $packages += @{title='Versalink 7025';url='http://download.support.xerox.com/pub/drivers/6510/drivers/win10/ar/XeroxSmartStart_1.3.35.0.exe';Arguments='/quiet';Destination=$SourcePath} }
            1 { $packages += @{title='WorkCenter 7225';url='http://download.support.xerox.com/pub/drivers/WC7220_WC7225/drivers/win10/ar/WC72XX_5.523.0.0_PrintSetup.exe';Arguments='/quiet';Destination=$SourcePath} }
            2 { $packages += @{title='WorkCenter 7225';url='http://download.support.xerox.com/pub/drivers/WC7220_WC7225/drivers/win10/ar/WC72XX_5.523.0.0_PrintSetup.exe';Arguments='/quiet';Destination=$SourcePath} }
            default { Write-Warning "Invalid floor number provided. Skipping printer driver installation." }
        }
        
        # Download packages
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Starting software downloads..." -ForegroundColor Cyan
        
        $webClient = New-Object System.Net.WebClient
        $totalPackages = $packages.Count
        $currentPackage = 0
        
        foreach ($package in $packages) {
            $currentPackage++
            $packageName = $package.title 
            $fileName = [System.Uri]::UnescapeDataString((Split-Path $package.url -Leaf))
            $destinationPath = Join-Path -Path $package.Destination -ChildPath $fileName
            
            if (-not (Test-Path -Path $destinationPath -PathType Leaf)) {
                try {
                    Write-Progress -Activity "Downloading packages" -Status "$currentPackage of $totalPackages - $packageName" -PercentComplete (($currentPackage / $totalPackages) * 100)
                    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Downloading $packageName..."
                    
                    $webClient.DownloadFile($package.url, $destinationPath)
                    
                    # Verify download
                    if (-not (Test-Path -Path $destinationPath -PathType Leaf)) {
                        throw "File not found after download attempt"
                    }
                    
                    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Successfully downloaded $packageName" -ForegroundColor Green
                }
                catch {
                    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ERROR downloading $packageName`: $_" -ForegroundColor Red
                    continue
                }
            }
            else {
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $packageName already exists, skipping download" -ForegroundColor Yellow
            }
        }
        
        # Rename 7zip file
        $7zipDownload = Get-ChildItem -Path $SourcePath -Filter "*7z*.exe" | Select-Object -First 1
        if ($7zipDownload) {
            Rename-Item -Path $7zipDownload.FullName -NewName "7zip.exe" -Force
        }
        
        # Install packages
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Starting software installations..." -ForegroundColor Cyan
        
        foreach ($package in $packages) {
            $packageName = $package.title 
            $fileName = [System.Uri]::UnescapeDataString((Split-Path $package.url -Leaf))
            $destinationPath = Join-Path -Path $package.Destination -ChildPath $fileName 
            $Arguments = $package.Arguments 
            
            if (Test-Path -Path $destinationPath -PathType Leaf) {
                try {
                    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Installing $packageName..."
                    
                    $process = Start-Process -FilePath $destinationPath -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
                    
                    if ($process.ExitCode -ne 0) {
                        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] WARNING: $packageName installation returned exit code $($process.ExitCode)" -ForegroundColor Yellow
                    }
                    else {
                        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Successfully installed $packageName" -ForegroundColor Green
                    }
                }
                catch {
                    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ERROR installing $packageName`: $_" -ForegroundColor Red
                }
            }
            else {
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Skipping $packageName - installer not found" -ForegroundColor Yellow
            }
        }
    }
    catch {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ERROR in Download-And-Install-Software: $_" -ForegroundColor Red
        throw
    }
    finally {
        if ($webClient) { $webClient.Dispose() }
    }
}
#endregion

#region Main Execution
try {
    # Get user floor input with validation
    do {
        $User_Floor = Read-Host "Which floor is the user located on? Please enter value from 0 to 2 only"
        $floorValid = $User_Floor -match '^[0-2]$'
        if (-not $floorValid) {
            Write-Host "Invalid input. Please enter 0, 1, or 2." -ForegroundColor Red
        }
    } while (-not $floorValid)
    
    # Execute functions
    CopyFilesfromSourcefolder -SourcePath $ODTPath -DestinationPath $TargetPath -Credential $Credentials
    Install-Office -InstallCommand $OfficeInstallationCommand
    Download-And-Install-Software -SourcePath $Source -UserFloor $User_Floor
    
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] All installations completed successfully!" -ForegroundColor Green
}
catch {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] SCRIPT FAILED: $_" -ForegroundColor Red
    exit 1
}
finally {
    Stop-Transcript
}
#endregion
