<#
.SYNOPSIS
    Syncs local folders to Amazon S3 with enhanced logging and error handling.
.DESCRIPTION
    This script synchronizes specified local folders to an S3 bucket using CloudBerry Explorer.
    It includes email notifications, detailed logging, and improved error handling.
.NOTES
    File Name      : S3Sync-Enhanced.ps1
    Prerequisites : CloudBerry Explorer for S3 PowerShell snapin
    Version       : 2.0
#>

#region Initialization
# Load CloudBerry snapin if not already loaded
if (-not (Get-PSSnapin -Name CloudBerryLab.Explorer.PSSnapIn -ErrorAction SilentlyContinue)) {
    try {
        Add-PSSnapin CloudBerryLab.Explorer.PSSnapIn -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to load CloudBerryLab.Explorer.PSSnapIn. Please install CloudBerry Explorer for S3."
        exit 1
    }
}

# Configuration - Replace these values
$config = @{
    AWSKey         = "YOURAWSKEY"                # AWS Access Key
    AWSSecret      = "YOURAWSSECRET"             # AWS Secret Key
    BucketName     = "BUCKETNAME"                # S3 Bucket Name
    ReducedRedundancy = $false                   # Set to $true to use RRS
    
    # Email settings
    EmailTo        = "it-support@example.com"    # Recipient email
    EmailFrom      = "alert@example.com"         # Sender email
    SMTPServer     = "mail.example.com"          # SMTP server
    SMTPPort       = 587                         # SMTP port
    EmailCredPath  = "C:\security\string.txt"    # Path to secure string password
    EmailUser      = "alert@example.com"         # SMTP username
    
    # Sync settings
    MaxFileAgeMins = -5                          # Max age for files to consider in sync
    ServerName     = $env:COMPUTERNAME           # Server name for notifications
    LogPath        = "C:\Logs\S3Sync.log"        # Log file path
}

# Create log directory if it doesn't exist
if (-not (Test-Path (Split-Path $config.LogPath -Parent))) {
    New-Item -ItemType Directory -Path (Split-Path $config.LogPath -Parent) -Force | Out-Null
}
#endregion

#region Functions
function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("INFO","WARNING","ERROR")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $config.LogPath -Value $logEntry
    Write-Host $logEntry -ForegroundColor $(if ($Level -eq "ERROR") {"Red"} elseif ($Level -eq "WARNING") {"Yellow"} else {"White"})
}

function SyncFolder {
    param (
        [string]$LocalFolderName,
        [string]$RemoteFolderName,
        [bool]$UseRRS = $false
    )
    
    try {
        Write-Log "Starting sync for folder: $LocalFolderName to $RemoteFolderName"
        
        if (-not (Test-Path $LocalFolderName -PathType Container)) {
            Write-Log "Local folder does not exist: $LocalFolderName" -Level "ERROR"
            return $null
        }
        
        $source = $local | Select-CloudFolder $LocalFolderName -ErrorAction Stop
        $s3folder = $config.BucketName + $RemoteFolderName
        $target = $s3 | Select-CloudFolder -Path $s3folder -ErrorAction Stop
        
        # Perform the sync
        $syncResult = $source | Copy-CloudSyncFolders $target -IncludeSubFolders -DeleteOnTarget -ErrorAction Stop
        
        if ($UseRRS) {
            $target | Set-CloudStorageClass -StorageClass rrs -ErrorAction SilentlyContinue
            Write-Log "Set Reduced Redundancy Storage for: $RemoteFolderName"
        }
        
        Write-Log "Successfully synced folder: $LocalFolderName"
        return $LocalFolderName
    }
    catch {
        Write-Log "Error syncing folder $LocalFolderName : $_" -Level "ERROR"
        return $null
    }
}

function Send-Notification {
    param (
        [string]$Subject,
        [string]$Body,
        [bool]$IsError = $false
    )
    
    try {
        if (-not (Test-Path $config.EmailCredPath)) {
            Write-Log "Email credential file not found: $($config.EmailCredPath)" -Level "WARNING"
            return
        }
        
        $password = Get-Content $config.EmailCredPath | ConvertTo-SecureString
        $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $config.EmailUser, $password
        
        $mailParams = @{
            To          = $config.EmailTo
            From        = $config.EmailFrom
            Port        = $config.SMTPPort
            SmtpServer  = $config.SMTPServer
            Credential  = $cred
            Subject     = "$($config.ServerName) - $Subject"
            Body        = $Body
            ErrorAction = "Stop"
        }
        
        if ($IsError) {
            $mailParams.Body += "`n`nLog excerpt:`n" + (Get-Content $config.LogPath -Tail 20 | Out-String)
        }
        
        Send-MailMessage @mailParams
        Write-Log "Notification email sent: $Subject"
    }
    catch {
        Write-Log "Failed to send notification email: $_" -Level "ERROR"
    }
}
#endregion

#region Main Execution
try {
    Write-Log "Starting S3 Sync Process"
    
    # Establish connections
    try {
        $s3 = Get-CloudS3Connection -Key $config.AWSKey -Secret $config.AWSSecret -ErrorAction Stop
        $local = Get-CloudFilesystemConnection -ErrorAction Stop
        Write-Log "Successfully connected to S3 and local filesystem"
    }
    catch {
        Write-Log "Failed to establish connections: $_" -Level "ERROR"
        Send-Notification -Subject "S3 Sync Connection Failed" -Body "Failed to connect to S3 or local filesystem" -IsError $true
        exit 1
    }
    
    # Define folders to sync
    $foldersToSync = @(
        @{Local="C:\Script"; Remote="/Script"}
        @{Local="C:\security"; Remote="/security"}
        @{Local="C:\inetpub\wwwroot"; Remote="/inetpub/wwwroot"}
        @{Local="C:\tmp"; Remote="/tmp"}
    )
    
    $successfulSyncs = @()
    
    # Process each folder
    foreach ($folder in $foldersToSync) {
        $result = SyncFolder -LocalFolderName $folder.Local -RemoteFolderName $folder.Remote -UseRRS $config.ReducedRedundancy
        if ($result) {
            $successfulSyncs += $result
        }
    }
    
    # Check for recently modified files
    if ($successfulSyncs.Count -gt 0) {
        $currDate = Get-Date
        $filesSynced = Get-ChildItem -Path $successfulSyncs -Recurse -File | 
                      Where-Object { $_.CreationTime -gt $currDate.AddMinutes($config.MaxFileAgeMins) }
        
        if ($filesSynced.Count -gt 0) {
            $messageBody = "The following files were synced to S3:`n`n"
            $messageBody += ($filesSynced | Select-Object FullName, LastWriteTime, Length | Format-Table -AutoSize | Out-String)
            
            Send-Notification -Subject "S3 Sync Completed Successfully" -Body $messageBody
        }
        else {
            Write-Log "No recently modified files found in synced folders"
        }
    }
    else {
        Write-Log "No folders were successfully synced" -Level "WARNING"
        Send-Notification -Subject "S3 Sync Failed" -Body "No folders were successfully synced to S3" -IsError $true
    }
    
    Write-Log "S3 Sync Process Completed"
}
catch {
    Write-Log "Unhandled error in main execution: $_" -Level "ERROR"
    Send-Notification -Subject "S3 Sync Critical Error" -Body "Script encountered an unhandled error" -IsError $true
    exit 1
}
#endregion
