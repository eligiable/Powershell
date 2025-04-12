<#
.SYNOPSIS
    Script to monitor specified folders for new files and email them as attachments.
.DESCRIPTION
    This script checks specified folders for files modified in the last 24 hours,
    collects them, and sends them via email with a summary of the files found.
.NOTES
    File Name      : Send-RecentFileAttachments.ps1
    Author         : Your Name
    Prerequisite   : PowerShell 5.1 or later
#>

# Configuration Section
$Config = @{
    FilePattern         = "*"  # Pattern for files to search for
    SearchFolders       = @(
        "D:\Folder_Name_1",
        "D:\Folder_Name_2",
        "D:\Folder_Name_3"
    )
    DaysToLookBack     = 1    # Number of days to look back for modified files
    CredentialFile      = "C:\security\string.txt"
    SmtpServer         = "mail.example.com"
    SmtpPort           = 587
    SmtpUsername       = "alert@example.com"
    SmtpToAddress      = "it-support@example.com"
    EmailSubjectPrefix = "Attached Files are added today"
}

# Initialize variables
$fileAttachments = @()
$messageBody = ""
$currentDate = Get-Date -Format "yyyy-MM-dd"
$ipAddress = (Get-NetIPAddress | Where-Object { $_.AddressFamily -eq 'IPv4' -and $_.InterfaceAlias -notlike '*Loopback*' }).IPAddress | Select-Object -First 1

try {
    # Get credential
    $password = Get-Content $Config.CredentialFile -ErrorAction Stop | ConvertTo-SecureString -ErrorAction Stop
    $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Config.SmtpUsername, $password

    # Find recently modified files
    $recentFiles = Get-ChildItem -Path $Config.SearchFolders -File -Recurse -ErrorAction SilentlyContinue | 
                   Where-Object { $_.LastWriteTime -ge (Get-Date).AddDays(-$Config.DaysToLookBack) }

    if ($recentFiles.Count -gt 0) {
        # Prepare email content
        $messageBody = "The following files were modified in the last $($Config.DaysToLookBack) day(s):`r`n`r`n"
        $messageBody += ($recentFiles.FullName -join "`r`n")
        $messageBody += "`r`n`r`nGenerated from server with IP: $ipAddress on $currentDate"

        $fileAttachments = $recentFiles.FullName
        $emailSubject = "$($Config.EmailSubjectPrefix) @ $ipAddress - $currentDate"

        # Send email
        Send-MailMessage -To $Config.SmtpToAddress `
                         -From $Config.SmtpUsername `
                         -Port $Config.SmtpPort `
                         -SmtpServer $Config.SmtpServer `
                         -Credential $credential `
                         -Subject $emailSubject `
                         -Body $messageBody `
                         -Attachments $fileAttachments `
                         -ErrorAction Stop

        Write-Host "Successfully sent email with $($recentFiles.Count) attachments."
    }
    else {
        Write-Host "No recently modified files found in the specified folders."
    }
}
catch {
    Write-Error "An error occurred: $_"
    # You might want to add additional error handling here, like sending an error notification
    exit 1
}

# Optional: Log execution
# $logEntry = "[$currentDate] Processed $($recentFiles.Count) files. IP: $ipAddress"
# Add-Content -Path "C:\logs\FileMonitor.log" -Value $logEntry
