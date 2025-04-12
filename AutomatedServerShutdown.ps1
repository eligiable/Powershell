<#
.SYNOPSIS
Automates server shutdowns on weekends and at specified times during the week.

.DESCRIPTION
This script shuts down servers:
- Every weekend (Saturday and Sunday)
- At specified times during weekdays (configurable)
Can be scheduled via Task Scheduler to run daily.

.NOTES
File Name      : AutomatedServerShutdown.ps1
Prerequisite   : PowerShell 5.1 or later, administrative rights
#>

# Configuration parameters - adjust these as needed
$servers = @("Server1", "Server2", "Server3")  # List of servers to manage
$weekdayShutdownTime = "20:00"                 # Weekday shutdown time (24-hour format)
$weekendShutdownTime = "18:00"                 # Weekend shutdown time (24-hour format)
$shutdownGracePeriod = 300                     # Seconds to wait before forced shutdown (5 minutes)
$logPath = "C:\Logs\ServerShutdowns.log"       # Log file path

# Email notification settings (optional)
$emailNotification = $true
$smtpServer = "smtp.yourcompany.com"
$smtpPort = 25
$emailFrom = "automation@yourcompany.com"
$emailTo = "admin@yourcompany.com"

# Create log directory if it doesn't exist
if (-not (Test-Path (Split-Path $logPath -Parent))) {
    New-Item -ItemType Directory -Path (Split-Path $logPath -Parent) -Force | Out-Null
}

function Write-Log {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $message"
    Add-Content -Path $logPath -Value $logEntry
    Write-Output $logEntry
}

function Send-EmailNotification {
    param (
        [string]$subject,
        [string]$body
    )
    try {
        Send-MailMessage -From $emailFrom -To $emailTo -Subject $subject -Body $body -SmtpServer $smtpServer -Port $smtpPort
        Write-Log "Email notification sent: $subject"
    }
    catch {
        Write-Log "Failed to send email notification: $_"
    }
}

function Shutdown-Server {
    param (
        [string]$serverName,
        [string]$reason
    )
    try {
        Write-Log "Attempting to shut down $serverName - Reason: $reason"
        
        # Check if server is reachable
        if (-not (Test-Connection -ComputerName $serverName -Count 1 -Quiet)) {
            Write-Log "$serverName is not reachable. Skipping shutdown."
            return
        }
        
        # Initiate shutdown
        $shutdownCmd = "shutdown /s /t $shutdownGracePeriod /c `"Automated shutdown: $reason`" /f"
        Invoke-Command -ComputerName $serverName -ScriptBlock {
            param($cmd)
            cmd.exe /c $cmd
        } -ArgumentList $shutdownCmd
        
        Write-Log "Shutdown command sent to $serverName successfully."
        
        if ($emailNotification) {
            $subject = "Server Shutdown Initiated: $serverName"
            $body = "Server $serverName is being shut down.`nReason: $reason`nTime: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            Send-EmailNotification -subject $subject -body $body
        }
    }
    catch {
        Write-Log "Error shutting down $serverName : $_"
        
        if ($emailNotification) {
            $subject = "FAILED: Server Shutdown for $serverName"
            $body = "Failed to shut down server $serverName.`nError: $_`nTime: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            Send-EmailNotification -subject $subject -body $body
        }
    }
}

# Main execution
Write-Log "=== Automated Server Shutdown Script Started ==="

$currentTime = Get-Date
$currentDay = $currentTime.DayOfWeek
$isWeekend = ($currentDay -eq "Saturday") -or ($currentDay -eq "Sunday")
$configuredShutdownTime = if ($isWeekend) { $weekendShutdownTime } else { $weekdayShutdownTime }

# Parse the configured shutdown time
$shutdownTime = [datetime]::ParseExact($configuredShutdownTime, "HH:mm", $null)
$shutdownDateTime = Get-Date -Year $currentTime.Year -Month $currentTime.Month -Day $currentTime.Day -Hour $shutdownTime.Hour -Minute $shutdownTime.Minute -Second 0

# Check if current time is within 5 minutes of scheduled shutdown time
if (($currentTime -ge $shutdownDateTime) -and ($currentTime -le $shutdownDateTime.AddMinutes(5))) {
    $reason = if ($isWeekend) { "Weekend shutdown" } else { "Weekday scheduled shutdown" }
    
    foreach ($server in $servers) {
        # Check if server should be excluded from shutdown (add your conditions here)
        $exclude = $false
        
        if (-not $exclude) {
            Shutdown-Server -serverName $server -reason $reason
        }
        else {
            Write-Log "Server $server excluded from shutdown."
        }
    }
}
else {
    Write-Log "Current time is not within scheduled shutdown window. No action taken."
}

Write-Log "=== Automated Server Shutdown Script Completed ==="
