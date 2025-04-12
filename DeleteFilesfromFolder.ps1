<#
.SYNOPSIS
    Automated cleanup of old files with notification system.
.DESCRIPTION
    This script deletes files older than specified days and sends email notification.
    Features include logging, error handling, and detailed reporting.
.NOTES
    Version: 2.0
    Author: Your Name
    Date: $(Get-Date -Format "yyyy-MM-dd")
#>

# Configuration Section
$config = @{
    # Folders to clean (add more as needed)
    FoldersToClean = @(
        "D:\Folder_Name\"
    )
    
    # Retention policy (days)
    DaysToKeep = 30
    
    # Email configuration
    EmailSettings = @{
        Username = "alert@example.com"
        PasswordFile = "C:\security\string.txt"
        Port = 587
        SmtpServer = "mail.example.com"
        Recipients = "it-support@example.com"
        FromAddress = "alert@example.com"
        Subject = "Cache Cleared from {Server_Name} @ {IP_Address}"
    }
    
    # System information
    ServerInfo = @{
        Name = $env:COMPUTERNAME
        IP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" }).IPAddress | Select-Object -First 1
    }
    
    # Logging configuration
    LogPath = "D:\Logs\FileCleanup.log"
    MaxLogAge = 30 # Days to keep logs
}

# Initialize logging
function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("INFO","WARNING","ERROR","SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp][$Level] $Message"
    
    # Create log directory if it doesn't exist
    if (-not (Test-Path (Split-Path $config.LogPath -Parent))) {
        New-Item -ItemType Directory -Path (Split-Path $config.LogPath -Parent) -Force | Out-Null
    }
    
    Add-Content -Path $config.LogPath -Value $logEntry
    Write-Host $logEntry -ForegroundColor $(switch ($Level) {
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        default { "White" }
    })
}

# Clean up old log files
function Clear-OldLogs {
    try {
        if (Test-Path $config.LogPath) {
            Get-ChildItem -Path (Split-Path $config.LogPath -Parent) -Filter "*.log" | 
                Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-$config.MaxLogAge) } | 
                Remove-Item -Force -ErrorAction Stop
            Write-Log "Cleaned up log files older than $($config.MaxLogAge) days" -Level "INFO"
        }
    } catch {
        Write-Log "Failed to clean up old log files: $_" -Level "WARNING"
    }
}

# Main execution
try {
    Write-Log "Script execution started"
    Clear-OldLogs

    # Load email credentials securely
    try {
        $password = Get-Content $config.EmailSettings.PasswordFile -ErrorAction Stop | ConvertTo-SecureString
        $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $config.EmailSettings.Username, $password
        Write-Log "Email credentials loaded successfully" -Level "SUCCESS"
    } catch {
        Write-Log "Failed to load email credentials: $_" -Level "ERROR"
        throw
    }

    # Process each folder
    $deletedFiles = @()
    $totalSpaceFreed = 0
    
    foreach ($folder in $config.FoldersToClean) {
        try {
            if (-not (Test-Path $folder)) {
                Write-Log "Folder not found: $folder" -Level "WARNING"
                continue
            }

            Write-Log "Processing folder: $folder"
            
            # Get files older than retention period
            $oldFiles = Get-ChildItem -Path $folder -Recurse -File -ErrorAction Stop | 
                       Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-$config.DaysToKeep) }
            
            if ($oldFiles.Count -gt 0) {
                Write-Log "Found $($oldFiles.Count) files older than $($config.DaysToKeep) days in $folder"
                
                # Calculate total size before deletion
                $spaceToFree = ($oldFiles | Measure-Object -Property Length -Sum).Sum / 1MB
                Write-Log "Attempting to free $([math]::Round($spaceToFree, 2)) MB from $folder"
                
                # Delete files
                $oldFiles | Remove-Item -Force -ErrorAction Stop
                $deletedFiles += $oldFiles
                $totalSpaceFreed += $spaceToFree
                
                Write-Log "Successfully deleted $($oldFiles.Count) files from $folder" -Level "SUCCESS"
            } else {
                Write-Log "No files older than $($config.DaysToKeep) days found in $folder"
            }
        } catch {
            Write-Log "Error processing folder $folder : $_" -Level "ERROR"
        }
    }

    # Send notification if files were deleted
    if ($deletedFiles.Count -gt 0) {
        try {
            $subject = $config.EmailSettings.Subject -replace "{Server_Name}", $config.ServerInfo.Name -replace "{IP_Address}", $config.ServerInfo.IP
            
            $messagebody = @"
The following cleanup operation was performed:

- Server: $($config.ServerInfo.Name) ($($config.ServerInfo.IP))
- Total files deleted: $($deletedFiles.Count)
- Approximate space freed: $([math]::Round($totalSpaceFreed, 2)) MB
- Retention period: $($config.DaysToKeep) days

Deleted files:
"@

            $deletedFiles | ForEach-Object { 
                $messagebody += "`r`n- $($_.FullName) (Created: $($_.CreationTime), Size: $([math]::Round($_.Length/1KB, 2)) KB)"
            }

            $messagebody += "`r`n`r`nThis is an automated message. Please do not reply."

            Send-MailMessage -To $config.EmailSettings.Recipients `
                            -From $config.EmailSettings.FromAddress `
                            -Port $config.EmailSettings.Port `
                            -SmtpServer $config.EmailSettings.SmtpServer `
                            -Credential $cred `
                            -Subject $subject `
                            -Body $messagebody `
                            -ErrorAction Stop
            
            Write-Log "Notification email sent successfully" -Level "SUCCESS"
        } catch {
            Write-Log "Failed to send notification email: $_" -Level "ERROR"
        }
    } else {
        Write-Log "No files were deleted - no notification sent"
    }

    Write-Log "Script completed successfully. Total space freed: $([math]::Round($totalSpaceFreed, 2)) MB" -Level "SUCCESS"
} catch {
    Write-Log "Script failed: $_" -Level "ERROR"
    exit 1
}
