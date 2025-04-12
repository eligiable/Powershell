<#
.SYNOPSIS
    Script to monitor specified folders for new files and email them as attachments.
.DESCRIPTION
    This script checks specified folders for files modified in the last 24 hours,
    collects their paths, and sends them via email with a summary.
.NOTES
    File Name      : FileMonitor.ps1
    Author         : Your Name
    Prerequisite   : PowerShell 5.1 or later
#>

# Configuration Section
$Config = @{
    # Folders to monitor (use full paths)
    SearchPaths = @(
        "D:\Folder_Name_1",
        "D:\Folder_Name_2",
        "D:\Folder_Name_3"
    )
    
    # File pattern to search for
    FilePattern = "*"
    
    # How many days back to look for modified files
    DaysBack = 1
    
    # Email settings
    SmtpServer = "mail.example.com"
    SmtpPort = 587
    SmtpUsername = "alert@example.com"
    SmtpPasswordFile = "C:\security\string.txt"  # Secure string file
    EmailFrom = "alert@example.com"
    EmailTo = "it-support@example.com"
    EmailSubject = "New Files Added - {0}"  # {0} will be replaced with date
}

# Initialize variables
$ErrorActionPreference = "Stop"
$currentDate = Get-Date -Format "yyyy-MM-dd"
$foundFiles = @()
$emailBody = "The following files were modified/added in the last $($Config.DaysBack) day(s):`r`n`r`n"
$logFile = "C:\logs\FileMonitor_$currentDate.log"

# Functions
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Add-Content -Path $logFile -Value $logEntry
}

function Get-LocalIPAddress {
    try {
        $ipAddress = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Ethernet*" | 
                      Where-Object { $_.IPAddress -ne '127.0.0.1' } | 
                      Select-Object -First 1).IPAddress
        return $ipAddress
    }
    catch {
        Write-Log "Failed to get local IP address: $_" -Level "WARNING"
        return "IP-Not-Found"
    }
}

# Main Script Execution
try {
    # Create log directory if it doesn't exist
    if (-not (Test-Path (Split-Path $logFile -Parent))) {
        New-Item -ItemType Directory -Path (Split-Path $logFile -Parent) -Force | Out-Null
    }
    
    Write-Log "Script started"
    
    # Get credential
    if (-not (Test-Path $Config.SmtpPasswordFile)) {
        throw "SMTP password file not found at $($Config.SmtpPasswordFile)"
    }
    
    $password = Get-Content $Config.SmtpPasswordFile | ConvertTo-SecureString
    $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Config.SmtpUsername, $password
    
    # Get local IP address
    $localIpAddress = Get-LocalIPAddress
    $Config.EmailSubject = $Config.EmailSubject -f $localIpAddress
    
    # Find files modified in the last X days
    $cutoffDate = (Get-Date).AddDays(-$Config.DaysBack)
    
    Write-Log "Searching for files modified after $cutoffDate in: $($Config.SearchPaths -join ', ')"
    
    $foundFiles = Get-ChildItem -Path $Config.SearchPaths -File -Recurse -Filter $Config.FilePattern | 
                  Where-Object { $_.LastWriteTime -ge $cutoffDate } | 
                  Sort-Object LastWriteTime
    
    if ($foundFiles.Count -gt 0) {
        Write-Log "Found $($foundFiles.Count) modified file(s)"
        
        # Build email body
        $emailBody += $foundFiles | ForEach-Object {
            "• $($_.FullName) (Modified: $($_.LastWriteTime))`r`n"
        } -join ""
        
        # Send email with attachments
        $mailParams = @{
            To          = $Config.EmailTo
            From        = $Config.EmailFrom
            Subject     = $Config.EmailSubject
            Body        = $emailBody
            SmtpServer  = $Config.SmtpServer
            Port        = $Config.SmtpPort
            Credential  = $credential
            Attachments = $foundFiles.FullName
            BodyAsHtml  = $false
        }
        
        Send-MailMessage @mailParams
        Write-Log "Email sent successfully with $($foundFiles.Count) attachment(s)"
    }
    else {
        Write-Log "No modified files found in the specified time period"
    }
}
catch {
    Write-Log "Error occurred: $_" -Level "ERROR"
    # Optionally send error notification
    try {
        Send-MailMessage -To $Config.EmailTo -From $Config.EmailFrom -Subject "File Monitor Error" `
                        -Body "An error occurred in the file monitor script:`r`n$_" `
                        -SmtpServer $Config.SmtpServer -Port $Config.SmtpPort -Credential $credential
    }
    catch {
        Write-Log "Failed to send error notification: $_" -Level "ERROR"
    }
}
finally {
    Write-Log "Script completed"
}
