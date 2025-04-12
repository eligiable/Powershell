<#
.SYNOPSIS
    Automated Software Installation Script
.DESCRIPTION
    Downloads and installs multiple software packages with enhanced logging and error handling.
    Also creates a local user account and installs .NET Framework 3.5 if needed.
.NOTES
    File Name      : SoftwareInstallerEnhanced.ps1
    Author         : Your Name
    Prerequisite   : PowerShell 5.1+, Windows 10/11, Admin privileges
    Version        : 2.0
#>

#region Configuration
$Config = @{
    DownloadFolder = "C:\Downloads"
    InstallerListFile = "Installers.txt"
    LogFile = "C:\Logs\SoftwareInstaller.log"
    SoftwarePackages = @(
        "7z1900-x64.exe",
        "ccsetup576.exe",
        "ChromeSetup.exe",
        "Firefox Installer.exe",
        "FoxitReader1011_Setup_Prom_IS.exe",
        "GoogleDriveFSSetup.exe",
        "TeamViewer_Setup.exe",
        "vlc-3.0.12-win64.exe",
        "Webex.msi",
        "WPSOffice_11.2.0.9984.exe",
        "ZoomInstaller.exe",
        "RingCentral.exe",
        "XeroxSmartStart_1.5.49.0.exe"
    )
    InstallArguments = @{
        "*.exe" = "/S /qn /norestart"
        "*.msi" = "/qn /norestart"
    }
    DotNetFeatureName = "NetFx3"
}
#endregion

#region Functions
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    try {
        if (-not (Test-Path -Path (Split-Path -Path $Config.LogFile -Parent))) {
            New-Item -ItemType Directory -Path (Split-Path -Path $Config.LogFile -Parent) -Force | Out-Null
        }
        $logEntry | Out-File -FilePath $Config.LogFile -Append -Encoding UTF8
    }
    catch {
        Write-Host "Failed to write to log file: $_" -ForegroundColor Red
    }
    
    switch ($Level) {
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "WARN"  { Write-Host $logEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        default { Write-Host $logEntry }
    }
}

function Test-Admin {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        Write-Log "Failed to verify admin privileges: $_" -Level "ERROR"
        return $false
    }
}

function Install-DotNetFramework {
    try {
        Write-Log "Checking .NET Framework 3.5 status..."
        $feature = Get-WindowsOptionalFeature -Online -FeatureName $Config.DotNetFeatureName -ErrorAction Stop
        
        if ($feature.State -ne "Enabled") {
            Write-Log ".NET Framework 3.5 is not installed. Installing now..."
            $result = Enable-WindowsOptionalFeature -Online -FeatureName $Config.DotNetFeatureName -All -NoRestart -ErrorAction Stop
            if ($result.RestartNeeded) {
                Write-Log ".NET Framework 3.5 installed successfully but requires a restart" -Level "WARN"
            } else {
                Write-Log ".NET Framework 3.5 installed successfully" -Level "SUCCESS"
            }
        } else {
            Write-Log ".NET Framework 3.5 is already installed"
        }
    }
    catch {
        Write-Log "Failed to install .NET Framework 3.5: $_" -Level "ERROR"
        return $false
    }
    return $true
}

function Download-Software {
    try {
        Write-Log "Creating download folder at $($Config.DownloadFolder)"
        New-Item -ItemType Directory -Path $Config.DownloadFolder -Force -ErrorAction Stop | Out-Null
        
        Write-Log "Reading installer URLs from $($Config.InstallerListFile)"
        $urls = Get-Content $Config.InstallerListFile -ErrorAction Stop
        
        foreach ($url in $urls) {
            try {
                $fileName = [System.IO.Path]::GetFileName($url)
                $outputPath = Join-Path -Path $Config.DownloadFolder -ChildPath $fileName
                
                Write-Log "Downloading $fileName from $url"
                Invoke-WebRequest -Uri $url -OutFile $outputPath -ErrorAction Stop
                
                if (Test-Path $outputPath) {
                    Write-Log "Successfully downloaded $fileName" -Level "SUCCESS"
                } else {
                    Write-Log "Download completed but file not found at $outputPath" -Level "WARN"
                }
            }
            catch {
                Write-Log "Failed to download $url : $_" -Level "ERROR"
            }
        }
    }
    catch {
        Write-Log "Failed to initialize downloads: $_" -Level "ERROR"
        return $false
    }
    return $true
}

function Install-Software {
    foreach ($package in $Config.SoftwarePackages) {
        $installPath = Join-Path -Path $Config.DownloadFolder -ChildPath $package
        
        if (Test-Path $installPath) {
            try {
                Write-Log "Installing $package..."
                
                # Determine appropriate silent install arguments
                $arguments = "/S /qn /norestart" # Default for .exe
                if ($package.EndsWith(".msi")) {
                    $arguments = "/qn /norestart"
                }
                
                # Special cases for specific installers
                switch -Wildcard ($package) {
                    "ChromeSetup.exe" { $arguments = "--silent --install" }
                    "Firefox*" { $arguments = "-ms" }
                    "vlc*" { $arguments = "/S" }
                }
                
                $process = Start-Process -FilePath $installPath -ArgumentList $arguments -Wait -PassThru -ErrorAction Stop
                
                if ($process.ExitCode -eq 0) {
                    Write-Log "$package installed successfully" -Level "SUCCESS"
                } else {
                    Write-Log "$package installation failed with exit code $($process.ExitCode)" -Level "ERROR"
                }
            }
            catch {
                Write-Log "Failed to install $package : $_" -Level "ERROR"
            }
        } else {
            Write-Log "Installer not found at $installPath" -Level "WARN"
        }
    }
}

function Create-LocalUser {
    try {
        Write-Log "Creating local user account..."
        $userName = Read-Host -Prompt "Please Enter a Username"
        
        if ([string]::IsNullOrWhiteSpace($userName)) {
            throw "Username cannot be empty"
        }
        
        # Check if user already exists
        if (Get-LocalUser -Name $userName -ErrorAction SilentlyContinue) {
            throw "User $userName already exists"
        }
        
        $password = Read-Host -Prompt "Enter password for $userName" -AsSecureString
        $description = Read-Host -Prompt "Enter user description (optional)"
        
        $userParams = @{
            Name        = $userName
            Password    = $password
            Description = $description
            ErrorAction = "Stop"
        }
        
        New-LocalUser @userParams
        Write-Log "User $userName created successfully" -Level "SUCCESS"
        
        # Add to Users group
        try {
            Add-LocalGroupMember -Group "Users" -Member $userName -ErrorAction Stop
            Write-Log "Added $userName to Users group" -Level "SUCCESS"
        }
        catch {
            Write-Log "Failed to add user to Users group: $_" -Level "WARN"
        }
    }
    catch {
        Write-Log "Failed to create user account: $_" -Level "ERROR"
    }
}
#endregion

#region Main Execution
Write-Log "Starting software installation process"

# Verify admin privileges
if (-not (Test-Admin)) {
    Write-Log "This script requires administrator privileges. Please run as administrator." -Level "ERROR"
    exit 1
}

# Install .NET Framework 3.5 if needed
if (-not (Install-DotNetFramework)) {
    Write-Log "Critical error with .NET Framework installation. Some software may not install properly." -Level "WARN"
}

# Download software
if (-not (Download-Software)) {
    Write-Log "Critical error downloading software. Exiting." -Level "ERROR"
    exit 1
}

# Install software
Install-Software

# Create local user
Create-LocalUser

Write-Log "Software installation process completed" -Level "SUCCESS"
#endregion
