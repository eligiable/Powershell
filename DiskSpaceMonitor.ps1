<#
.SYNOPSIS
    Monitors disk space and sends email alerts when free space is low.
.DESCRIPTION
    Checks all logical drives with type 3 (fixed disks) and sends an email alert if free space is 10% or less.
.NOTES
    File Name      : DiskSpaceMonitor.ps1
    Author         : Your Name
    Prerequisite   : PowerShell 5.1 or later
#>

# Configuration Parameters
$Client = "Name_TO_Represent_THE_Server"
$Threshold = 0.1  # 10% free space threshold

# Email Parameters
$EmailConfig = @{
    From        = "alert@example.com"
    To          = "it-support@example.com"
    Cc          = "backup-support@example.com"  # Added CC recipient
    SMTPServer  = "mail.example.com"
    SMTPPort    = 587
    Username    = "alert@example.com"
    Credential  = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username, (Get-Content -Path "C:\security\string.txt" | ConvertTo-SecureString)
    Subject     = "Urgent: Disk Space is Low in $Client $($env:COMPUTERNAME)"
    Priority    = "High"  # Added priority
    BodyAsHtml  = $true   # Send HTML formatted email
}

# Get Disk Information
try {
    $LowDisks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType = 3" | 
                Where-Object { $_.FreeSpace / $_.Size -le $Threshold } |
                Select-Object @(
                    "DeviceID",
                    @{Name = "FreeSpace(%)"; Expression = { [math]::Round(($_.FreeSpace / $_.Size) * 100, 2) }},
                    @{Name = "TotalSize(GB)"; Expression = { [math]::Round($_.Size / 1GB, 2) }},
                    @{Name = "FreeSpace(GB)"; Expression = { [math]::Round($_.FreeSpace / 1GB, 2) }},
                    @{Name = "UsedSpace(GB)"; Expression = { [math]::Round(($_.Size - $_.FreeSpace) / 1GB, 2) }},
                    @{Name = "UsedSpace(%)"; Expression = { [math]::Round(100 - ($_.FreeSpace / $_.Size * 100), 2) }}
                )

    if ($LowDisks) {
        # Generate HTML table for email body
        $HTMLBody = @"
<html>
<head>
<style>
    body { font-family: Arial, sans-serif; }
    table { border-collapse: collapse; width: 100%; }
    th { background-color: #FF6B6B; color: white; text-align: left; padding: 8px; }
    td { border: 1px solid #ddd; padding: 8px; }
    tr:nth-child(even) { background-color: #f2f2f2; }
    .warning { color: #D8000C; background-color: #FFD2D2; }
</style>
</head>
<body>
<h2 class='warning'>⚠️ Low Disk Space Alert</h2>
<p>Server: <strong>$Client $($env:COMPUTERNAME)</strong></p>
<p>Time: <strong>$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</strong></p>
<p>The following disks are below the $($Threshold * 100)% free space threshold:</p>
$($LowDisks | ConvertTo-Html -Fragment)
<br>
<p>Please take immediate action to free up disk space.</p>
</body>
</html>
"@

        # Send Email Alert
        try {
            Send-MailMessage @EmailConfig -Body $HTMLBody -ErrorAction Stop
            Write-Host "Alert email sent successfully at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        }
        catch {
            Write-Error "Failed to send email: $_"
            # You could add additional error handling here, like writing to event log
        }
    }
    else {
        Write-Host "No disks below threshold found. Monitoring complete at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    }
}
catch {
    Write-Error "Error occurred while checking disk space: $_"
    # You could add additional error handling here, like sending a different alert
}
