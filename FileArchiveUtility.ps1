<#
.SYNOPSIS
    Archives old files and sends notification emails.
.DESCRIPTION
    This script archives files older than 30 days from specified folders,
    compresses them, moves them to network locations, and sends email notifications.
.NOTES
    File Name      : FileArchiveUtility.ps1
    Author         : Your Name
    Prerequisite   : PowerShell 5.1 or later
#>

# Configuration Section
$Config = @{
    RootFolder          = "C:\tmp"
    TempFolderRoot      = "C:\Temp_Archive_"
    NetworkArchivePath  = "\\Network_PATH"
    DaysToArchive       = 30
    EmailConfig         = @{
        Username        = "alert@example.com"
        PasswordFile    = "C:\security\string.txt"
        SmtpServer      = "mail.example.com"
        Port            = 587
        ToAddress       = "it-support@example.com"
        FromAddress     = "alert@example.com"
    }
    LogPath            = "C:\Logs\FileArchive_$(Get-Date -Format 'yyyyMMdd').log"
}

# Initialize logging
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp][$Level] $Message"
    Add-Content -Path $Config.LogPath -Value $logEntry
    Write-Host $logEntry
}

try {
    # Create log directory if it doesn't exist
    if (-not (Test-Path (Split-Path $Config.LogPath -Parent))) {
        New-Item -ItemType Directory -Path (Split-Path $Config.LogPath -Parent) -Force | Out-Null
    }

    Write-Log "Script execution started"

    #region Archive Old Files from Root Folder
    Write-Log "Processing files in root folder: $($Config.RootFolder)"
    
    $archiveDate = Get-Date -Format "yyyy-MM-dd"
    $tempFinalFolder = "$($Config.TempFolderRoot)$archiveDate"
    $zipFileName = "Archive-$archiveDate.zip"
    $zipPath = Join-Path -Path $Config.RootFolder -ChildPath $zipFileName
    
    # Create temporary folder for archiving
    try {
        New-Item -ItemType Directory -Path $tempFinalFolder -Force -ErrorAction Stop | Out-Null
        Write-Log "Created temporary folder: $tempFinalFolder"
    } catch {
        Write-Log "Failed to create temporary folder: $_" -Level "ERROR"
        throw
    }

    # Get files older than specified days
    $cutoffDate = (Get-Date).AddDays(-$Config.DaysToArchive)
    $filesToArchive = Get-ChildItem -Path $Config.RootFolder -File | 
                     Where-Object { $_.LastWriteTime -lt $cutoffDate }
    
    if ($filesToArchive.Count -gt 0) {
        Write-Log "Found $($filesToArchive.Count) files to archive"
        
        # Move files to temporary location
        $movedFiles = 0
        foreach ($file in $filesToArchive) {
            try {
                Move-Item -Path $file.FullName -Destination $tempFinalFolder -ErrorAction Stop
                $movedFiles++
            } catch {
                Write-Log "Failed to move file $($file.Name): $_" -Level "ERROR"
            }
        }
        Write-Log "Successfully moved $movedFiles files to temporary folder"

        # Compress files
        try {
            Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
            [System.IO.Compression.ZipFile]::CreateFromDirectory(
                $tempFinalFolder,
                $zipPath,
                [System.IO.Compression.CompressionLevel]::Optimal,
                $false
            )
            Write-Log "Created archive: $zipPath"
        } catch {
            Write-Log "Failed to create archive: $_" -Level "ERROR"
            throw
        }

        # Move archive to network location
        try {
            $networkDestination = Join-Path -Path $Config.NetworkArchivePath -ChildPath $zipFileName
            Move-Item -Path $zipPath -Destination $networkDestination -ErrorAction Stop
            Write-Log "Moved archive to network location: $networkDestination"
        } catch {
            Write-Log "Failed to move archive to network location: $_" -Level "ERROR"
            throw
        }
    } else {
        Write-Log "No files found to archive in root folder"
    }

    # Clean up temporary folder
    try {
        Remove-Item -Path $tempFinalFolder -Recurse -Force -ErrorAction Stop
        Write-Log "Removed temporary folder: $tempFinalFolder"
    } catch {
        Write-Log "Failed to remove temporary folder: $_" -Level "ERROR"
    }
    #endregion

    #region Process Success Folder
    $successFolder = "C:\Folder_Name"
    Write-Log "Processing success folder: $successFolder"
    
    $successFiles = Get-ChildItem -Path "$successFolder\*.*" -File | 
                   Where-Object { $_.LastWriteTime -lt $cutoffDate }
    
    if ($successFiles.Count -gt 0) {
        Write-Log "Found $($successFiles.Count) files to move from success folder"
        
        # Prepare email message
        $localIpAddress = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" }).IPAddress | Select-Object -First 1
        $title = "Success Transactions been Archived for more than $($Config.DaysToArchive) days in $localIpAddress in $env:computername"
        $messageBody = "The following files have been archived:`r`n`r`n"
        $messageBody += ($successFiles.Name -join "`r`n")
        
        # Move files and send email
        try {
            $movedSuccessFiles = 0
            foreach ($file in $successFiles) {
                try {
                    Move-Item -Path $file.FullName -Destination $Config.NetworkArchivePath -ErrorAction Stop
                    $movedSuccessFiles++
                } catch {
                    Write-Log "Failed to move file $($file.Name): $_" -Level "ERROR"
                }
            }
            Write-Log "Successfully moved $movedSuccessFiles files from success folder"

            # Send email notification
            try {
                $password = Get-Content $Config.EmailConfig.PasswordFile | ConvertTo-SecureString
                $credential = New-Object System.Management.Automation.PSCredential ($Config.EmailConfig.Username, $password)
                
                Send-MailMessage -To $Config.EmailConfig.ToAddress `
                                -From $Config.EmailConfig.FromAddress `
                                -Subject $title `
                                -Body $messageBody `
                                -SmtpServer $Config.EmailConfig.SmtpServer `
                                -Port $Config.EmailConfig.Port `
                                -Credential $credential `
                                -ErrorAction Stop
                
                Write-Log "Successfully sent email notification"
            } catch {
                Write-Log "Failed to send email notification: $_" -Level "ERROR"
            }
        } catch {
            Write-Log "Error processing success folder: $_" -Level "ERROR"
        }
    } else {
        Write-Log "No files found to move from success folder"
    }
    #endregion

    Write-Log "Script execution completed successfully"
} catch {
    Write-Log "Script encountered an error: $_" -Level "ERROR"
    exit 1
}
