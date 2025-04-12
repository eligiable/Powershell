<#
.SYNOPSIS
    Monitors specified folders for recently created files and sends email alerts.
.DESCRIPTION
    This script checks designated folders for any files created within the last X minutes
    and sends an email notification with the file details if any are found.
.NOTES
    File Name      : FolderMonitor.ps1
    Author         : Your Name
    Prerequisite   : PowerShell 5.1 or later
#>

# Configuration Parameters
param (
    [string]$FilePattern = "*",
    [int]$MinutesThreshold = -5,
    [string[]]$MonitorFolders = @(
        "C:\Folder_Name_1",
        "C:\Folder_Name_2",
        "C:\Folder_Name_3"
    ),
    [string]$SmtpServer = "mail.example.com",
    [int]$SmtpPort = 587,
    [string]$SmtpFrom = "alert@example.com",
    [string]$SmtpTo = "it-support@example.com",
    [string]$CredentialFile = "C:\security\string.txt"
)

# Initialize variables
$currentDate = Get-Date
$cutoffTime = $currentDate.AddMinutes($MinutesThreshold)
$foundFiles = @()
$localIpAddress = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" } | Select-Object -First 1).IPAddress
$computerName = $env:COMPUTERNAME
$emailSubject = "URGENT: New Files Detected on $computerName ($localIpAddress)"

# Validate folders exist before scanning
$validFolders = @()
foreach ($folder in $MonitorFolders) {
    if (Test-Path -Path $folder -PathType Container) {
        $validFolders += $folder
    } else {
        Write-Warning "Folder not found: $folder"
    }
}

if ($validFolders.Count -eq 0) {
    throw "No valid folders to monitor. Script terminated."
}

try {
    # Search for recently created files
    $foundFiles = Get-ChildItem -Path $validFolders -File -Recurse -Filter $FilePattern | 
                  Where-Object { $_.CreationTime -ge $cutoffTime } |
                  Sort-Object CreationTime -Descending
    
    # Prepare email if files found
    if ($foundFiles.Count -gt 0) {
        # Create HTML formatted message body
        $messageBody = @"
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; }
        h2 { color: #d9534f; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        tr:nth-child(even) { background-color: #f9f9f9; }
    </style>
</head>
<body>
    <h2>New Files Detected on $computerName ($localIpAddress)</h2>
    <p><strong>Scan Time:</strong> $($currentDate.ToString('yyyy-MM-dd HH:mm:ss'))</p>
    <p><strong>Files Created Since:</strong> $($cutoffTime.ToString('yyyy-MM-dd HH:mm:ss'))</p>
    
    <table>
        <thead>
            <tr>
                <th>File Name</th>
                <th>Path</th>
                <th>Created</th>
                <th>Size (KB)</th>
            </tr>
        </thead>
        <tbody>
"@

        foreach ($file in $foundFiles) {
            $messageBody += @"
            <tr>
                <td>$($file.Name)</td>
                <td>$($file.DirectoryName)</td>
                <td>$($file.CreationTime.ToString('yyyy-MM-dd HH:mm:ss'))</td>
                <td>$([math]::Round($file.Length/1KB, 2))</td>
            </tr>
"@
        }

        $messageBody += @"
        </tbody>
    </table>
    <p><strong>Total Files Found:</strong> $($foundFiles.Count)</p>
</body>
</html>
"@

        # Load SMTP credentials securely
        if (-not (Test-Path -Path $CredentialFile)) {
            throw "Credential file not found at $CredentialFile"
        }
        
        $securePassword = Get-Content $CredentialFile | ConvertTo-SecureString
        $smtpCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $SmtpFrom, $securePassword

        # Send email notification
        Send-MailMessage -To $SmtpTo `
                        -From $SmtpFrom `
                        -Subject $emailSubject `
                        -Body $messageBody `
                        -BodyAsHtml `
                        -SmtpServer $SmtpServer `
                        -Port $SmtpPort `
                        -Credential $smtpCredential `
                        -Priority High `
                        -ErrorAction Stop

        Write-Output "Notification sent for $($foundFiles.Count) newly created files."
    } else {
        Write-Output "No recently created files found."
    }
}
catch {
    Write-Error "An error occurred: $_"
    # You could add additional error notification here if needed
    exit 1
}
