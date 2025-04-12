<#
.SYNOPSIS
    Monitors files for changes and sends alerts if no changes detected.
.DESCRIPTION
    This script compares files in two directories, sends email alerts if files haven't changed,
    manages file synchronization, and restarts a specified service.
.NOTES
    Version: 1.1
    Author: Your Name
    Date: $(Get-Date -Format "yyyy-MM-dd")
#>

# Configuration Section
$config = @{
    EmailSettings = @{
        Username = "alert@example.com"
        PasswordFile = "C:\security\string.txt"
        Port = 587
        SmtpServer = "mail.example.com"
        Recipients = "it-support@example.com", "someoneelse@example.com"
        FromAddress = "alert@example.com"
    }
    Paths = @{
        Source = "C:\tmp\Folder_Name\"
        Comparison = "C:\tmp-match\"
    }
    ServiceName = "Service_Name"
    CheckMinutes = 5
    LogPath = "C:\logs\FileMonitor.log"
}

# Initialize logging
function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("INFO","WARNING","ERROR")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp][$Level] $Message"
    Add-Content -Path $config.LogPath -Value $logEntry
    Write-Host $logEntry
}

try {
    # Create log directory if it doesn't exist
    if (-not (Test-Path (Split-Path $config.LogPath -Parent))) {
        New-Item -ItemType Directory -Path (Split-Path $config.LogPath -Parent) -Force | Out-Null
    }

    Write-Log "Script execution started"

    # Load email credentials securely
    try {
        $password = Get-Content $config.EmailSettings.PasswordFile -ErrorAction Stop | ConvertTo-SecureString
        $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $config.EmailSettings.Username, $password
        Write-Log "Email credentials loaded successfully"
    } catch {
        Write-Log "Failed to load email credentials: $_" -Level "ERROR"
        throw
    }

    # Get files to compare
    $LastFilesToCheck = Get-ChildItem -Path $config.Paths.Comparison -ErrorAction SilentlyContinue
    $cutoffTime = (Get-Date).AddMinutes(-$config.CheckMinutes)
    $CurrentFilesToCheck = Get-ChildItem -Path $config.Paths.Source -Filter *.txt -ErrorAction Stop | 
                          Where-Object {$_.LastWriteTime -ge $cutoffTime}

    if (-not $CurrentFilesToCheck) {
        Write-Log "No current files found matching criteria in $($config.Paths.Source)" -Level "WARNING"
    }

    # Compare files
    $comparison = Compare-Object -ReferenceObject $LastFilesToCheck -DifferenceObject $CurrentFilesToCheck `
                -Property Name, LastWriteTime -IncludeEqual -ErrorAction Stop

    if ($comparison) {
        $unchangedFiles = $comparison | Where-Object {$_.SideIndicator -eq "=="}
        
        if ($unchangedFiles) {
            Write-Log "Found $($unchangedFiles.Count) unchanged files"
            
            $messagebody = @"
It seems that files have not changed in the previous $($config.CheckMinutes) minutes. 
Please check the following files:

"@

            foreach ($file in $CurrentFilesToCheck) {
                $messagebody += "$($file.FullName) (Last Modified: $($file.LastWriteTime))`r`n"
            }

            $subject = "Files not changed in $($config.CheckMinutes) minutes - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"

            try {
                Send-MailMessage -To $config.EmailSettings.Recipients `
                                -From $config.EmailSettings.FromAddress `
                                -Port $config.EmailSettings.Port `
                                -SmtpServer $config.EmailSettings.SmtpServer `
                                -Credential $cred `
                                -Subject $subject `
                                -Body $messagebody `
                                -ErrorAction Stop
                Write-Log "Alert email sent successfully"
            } catch {
                Write-Log "Failed to send email: $_" -Level "ERROR"
            }
        }
    } else {
        Write-Log "No files to compare or comparison failed"
    }

    # File management
    try {
        # Clear comparison directory
        if (Test-Path $config.Paths.Comparison) {
            Remove-Item -Path "$($config.Paths.Comparison)*" -Force -ErrorAction Stop
            Write-Log "Cleared comparison directory"
        } else {
            New-Item -ItemType Directory -Path $config.Paths.Comparison -Force | Out-Null
            Write-Log "Created comparison directory"
        }

        # Copy new files to comparison directory
        if ($CurrentFilesToCheck) {
            $CurrentFilesToCheck | Copy-Item -Destination $config.Paths.Comparison -Force -ErrorAction Stop
            Write-Log "Copied $($CurrentFilesToCheck.Count) files to comparison directory"
        }
    } catch {
        Write-Log "File management error: $_" -Level "ERROR"
    }

    # Service management
    try {
        $service = Get-Service -Name $config.ServiceName -ErrorAction Stop
        if ($service.Status -ne "Stopped") {
            Write-Log "Stopping $($config.ServiceName) service"
            Stop-Service -Name $config.ServiceName -Force -ErrorAction Stop
            
            # Wait for service to stop
            $timeout = (Get-Date).AddSeconds(30)
            while ((Get-Service -Name $config.ServiceName).Status -ne "Stopped" -and (Get-Date) -lt $timeout) {
                Start-Sleep -Seconds 2
            }
        }

        Write-Log "Starting $($config.ServiceName) service"
        Start-Service -Name $config.ServiceName -ErrorAction Stop
        
        # Verify service started
        Start-Sleep -Seconds 5
        if ((Get-Service -Name $config.ServiceName).Status -eq "Running") {
            Write-Log "Service restarted successfully"
        } else {
            Write-Log "Service failed to start" -Level "WARNING"
        }
    } catch {
        Write-Log "Service management error: $_" -Level "ERROR"
    }

    Write-Log "Script execution completed successfully"
} catch {
    Write-Log "Script failed: $_" -Level "ERROR"
    exit 1
}
