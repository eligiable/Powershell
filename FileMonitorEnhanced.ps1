<#
.SYNOPSIS
    File Monitoring and Alerting Script
.DESCRIPTION
    Monitors a folder for recently modified XML files, restarts a service if found,
    and sends email alerts with enhanced logging and error handling.
.NOTES
    File Name      : FileMonitorEnhanced.ps1
    Author         : Your Name
    Prerequisite   : PowerShell 5.1+
    Version        : 2.0
#>

#region Configuration Parameters
$Config = @{
    # File Monitoring Configuration
    Monitor = @{
        FolderPath = "C:\Folder_Name"
        FileFilter = "*.xml"
        MaxMinutes = -5  # Negative value looks back in time
        CheckSubfolders = $false
    }
    
    # Service Configuration
    Service = @{
        Name = "Service_Name"
        RestartTimeout = 30  # Seconds to wait for service to restart
        LogFile = @{
            Source = "C:\tmp\FileInspectorLog.txt"
            Destination = "C:\fileinsplog\FileInspectorLog.txt"
        }
    }
    
    # Email Configuration
    Email = @{
        Enabled = $true
        SmtpServer = "mail.example.com"
        SmtpPort = 587
        To = "it-support@example.com"
        From = "alert@example.com"
        CredentialFile = "C:\security\string.txt"
        SubjectPrefix = "[URGENT]"
        ThrottleMinutes = 30  # Minimum minutes between repeat alerts
    }
    
    # Logging Configuration
    Logging = @{
        Enabled = $true
        LogPath = "C:\Logs\FileMonitor"
        LogName = "FileMonitor.log"
        MaxLogSizeMB = 10
        MaxLogAgeDays = 30
    }
}
#endregion

#region Initialization
# Create log directory if it doesn't exist
if ($Config.Logging.Enabled -and (-not (Test-Path -Path $Config.Logging.LogPath))) {
    try {
        New-Item -ItemType Directory -Path $Config.Logging.LogPath -Force -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Warning "Failed to create log directory: $_"
        $Config.Logging.Enabled = $false
    }
}

# Initialize log file path
$LogFile = Join-Path -Path $Config.Logging.LogPath -ChildPath $Config.Logging.LogName

# Initialize email credentials if enabled
if ($Config.Email.Enabled) {
    try {
        $securePassword = Get-Content $Config.Email.CredentialFile | ConvertTo-SecureString -ErrorAction Stop
        $Config.Email.Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Config.Email.From, $securePassword
    }
    catch {
        Write-Warning "Failed to load email credentials: $_"
        $Config.Email.Enabled = $false
    }
}

# Get local IP address
try {
    $Config.LocalIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" } | Select-Object -First 1).IPAddress
}
catch {
    $Config.LocalIP = "Unknown"
    Write-Warning "Failed to get local IP address: $_"
}

# Initialize last alert time for email throttling
$script:LastAlertTime = $null
#endregion

#region Functions
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    if ($Config.Logging.Enabled) {
        try {
            $logEntry | Out-File -FilePath $LogFile -Append -Encoding UTF8
        }
        catch {
            Write-Warning "Failed to write to log file: $_"
        }
    }
    
    # Also output to console
    switch ($Level) {
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "WARN"  { Write-Host $logEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        default { Write-Host $logEntry }
    }
}

function Send-AlertEmail {
    param(
        [string[]]$FileList,
        [bool]$ForceSend = $false
    )
    
    if (-not $Config.Email.Enabled) {
        return
    }
    
    # Check if we should throttle this alert
    if (-not $ForceSend -and $script:LastAlertTime -and 
        ((New-TimeSpan -Start $script:LastAlertTime -End (Get-Date)).TotalMinutes -lt $Config.Email.ThrottleMinutes) {
        Write-Log "Skipping email alert due to throttling (last alert sent at $script:LastAlertTime)" -Level "INFO"
        return
    }
    
    try {
        $subject = "$($Config.Email.SubjectPrefix) Files Found in Inbound Folder on $($Config.LocalIP) ($($env:computername))"
        $body = @"
The following files were found in the inbound folder (modified within last $(-$Config.Monitor.MaxMinutes) minutes):

$($FileList -join "`r`n")

Server: $($env:computername)
IP Address: $($Config.LocalIP)
Time: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@
        
        $mailParams = @{
            To         = $Config.Email.To
            From       = $Config.Email.From
            Subject    = $subject
            Body       = $body
            SmtpServer = $Config.Email.SmtpServer
            Port       = $Config.Email.SmtpPort
            Credential = $Config.Email.Credential
            Priority   = "High"
            UseSsl     = $true
        }
        
        Send-MailMessage @mailParams -ErrorAction Stop
        $script:LastAlertTime = Get-Date
        Write-Log "Sent alert email for $($FileList.Count) files" -Level "SUCCESS"
    }
    catch {
        Write-Log "Failed to send alert email: $_" -Level "ERROR"
    }
}

function Restart-TargetService {
    try {
        $service = Get-Service -Name $Config.Service.Name -ErrorAction Stop
        
        Write-Log "Current service status: $($service.Status)"
        
        if ($service.Status -ne 'Running') {
            Write-Log "Service is not running. Starting service..."
            Start-Service -Name $Config.Service.Name -ErrorAction Stop
        }
        else {
            Write-Log "Restarting service..."
            Restart-Service -Name $Config.Service.Name -Force -ErrorAction Stop
        }
        
        # Wait for service to reach running state
        $service.WaitForStatus('Running', (New-TimeSpan -Seconds $Config.Service.RestartTimeout))
        Write-Log "Service restarted successfully" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Failed to restart service: $_" -Level "ERROR"
        return $false
    }
}

function Copy-ServiceLog {
    try {
        if (Test-Path -Path $Config.Service.LogFile.Source -ErrorAction Stop) {
            # Ensure destination directory exists
            $destDir = Split-Path -Path $Config.Service.LogFile.Destination -Parent
            if (-not (Test-Path -Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force -ErrorAction Stop | Out-Null
            }
            
            Copy-Item -Path $Config.Service.LogFile.Source -Destination $Config.Service.LogFile.Destination -Force -ErrorAction Stop
            Write-Log "Copied service log to $($Config.Service.LogFile.Destination)" -Level "SUCCESS"
            return $true
        }
        else {
            Write-Log "Service log source file not found at $($Config.Service.LogFile.Source)" -Level "WARN"
            return $false
        }
    }
    catch {
        Write-Log "Failed to copy service log: $_" -Level "ERROR"
        return $false
    }
}

function Rotate-LogFile {
    param(
        [string]$LogPath,
        [string]$LogName,
        [int]$MaxSizeMB,
        [int]$MaxAgeDays
    )
    
    $logFile = Join-Path -Path $LogPath -ChildPath $LogName
    
    if (Test-Path -Path $logFile) {
        $logItem = Get-Item -Path $logFile
        
        # Rotate if file is too large
        if ($logItem.Length -gt ($MaxSizeMB * 1MB)) {
            $timestamp = Get-Date -Format "yyyyMMddHHmmss"
            $archiveName = $LogName -replace '\.log$', "_$timestamp.log"
            $archivePath = Join-Path -Path $LogPath -ChildPath $archiveName
            
            try {
                Move-Item -Path $logFile -Destination $archivePath -Force
                Write-Log "Rotated log file to $archiveName" -LogFile $archivePath
            }
            catch {
                Write-Warning "Failed to rotate log file: $_"
            }
        }
        
        # Clean up old log files
        Get-ChildItem -Path $LogPath -Filter "$($LogName -replace '\.log$','_*.log')" |
            Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$MaxAgeDays) } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
}
#endregion

#region Main Script Execution
Write-Log "Starting file monitoring in $($Config.Monitor.FolderPath)"

# Rotate log file if needed
if ($Config.Logging.Enabled) {
    Rotate-LogFile -LogPath $Config.Logging.LogPath -LogName $Config.Logging.LogName `
                   -MaxSizeMB $Config.Logging.MaxLogSizeMB -MaxAgeDays $Config.Logging.MaxLogAgeDays
}

# Check for recently modified files
try {
    $cutoffTime = (Get-Date).AddMinutes($Config.Monitor.MaxMinutes)
    $fileFilter = Join-Path -Path $Config.Monitor.FolderPath -ChildPath $Config.Monitor.FileFilter
    
    $recentFiles = Get-ChildItem -Path $fileFilter -File -ErrorAction Stop |
                   Where-Object { $_.LastWriteTime -ge $cutoffTime } |
                   Sort-Object LastWriteTime
    
    if ($recentFiles.Count -gt 0) {
        Write-Log "Found $($recentFiles.Count) recently modified files" -Level "WARN"
        
        # Copy service log
        Copy-ServiceLog
        
        # Restart service
        $serviceRestarted = Restart-TargetService
        
        # Send alert email
        Send-AlertEmail -FileList $recentFiles.Name -ForceSend:(-not $serviceRestarted)
        
        # Log file details
        $recentFiles | ForEach-Object {
            Write-Log "Found file: $($_.Name) (Last modified: $($_.LastWriteTime))"
        }
    }
    else {
        Write-Log "No recently modified files found" -Level "INFO"
    }
}
catch {
    Write-Log "Error during file monitoring: $_" -Level "ERROR"
    Send-AlertEmail -FileList @("Monitoring error occurred - check logs") -ForceSend $true
}

Write-Log "File monitoring completed"
#endregion
