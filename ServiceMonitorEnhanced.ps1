<#
.SYNOPSIS
    Service Monitoring and Auto-Recovery Script
.DESCRIPTION
    Monitors specified services, sends email alerts when services are stopped,
    and automatically attempts to restart them with enhanced logging and error handling.
.NOTES
    File Name      : ServiceMonitorEnhanced.ps1
    Author         : Your Name
    Prerequisite   : PowerShell 5.1+
    Version        : 2.0
#>

#region Configuration Parameters
$Config = @{
    ClientName = "Name_TO_Represent_THE_Server"  # Client/Organization name for reporting
    ServerName = "A1S2D3F-A1S2D3F"              # Server to monitor (use $env:computername for local)
    
    # Services to monitor (add your service names here)
    ServicesToMonitor = @(
        "Service_Name_1",
        "Service_Name_2"
    )
    
    # Email Configuration
    Email = @{
        Enabled         = $true
        From           = "alert@example.com"
        To             = "it-support@example.com"
        SmtpServer     = "mail.example.com"
        SmtpPort       = 587
        Username       = "alert@example.com"
        PasswordFile   = "C:\security\string.txt"  # Secure string file
        SubjectPrefix  = "[Service Monitor Alert]"
    }
    
    # Logging Configuration
    Logging = @{
        Enabled       = $true
        LogPath       = "C:\Logs\ServiceMonitor"
        LogName       = "ServiceMonitor.log"
        MaxLogSizeMB  = 10
        MaxLogAgeDays = 30
    }
    
    # Service Recovery Configuration
    Recovery = @{
        AttemptRestart       = $true
        MaxRestartAttempts   = 3
        DelayBetweenAttempts = 5  # seconds
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

# Initialize email credentials if enabled
if ($Config.Email.Enabled) {
    try {
        $securePassword = Get-Content $Config.Email.PasswordFile | ConvertTo-SecureString -ErrorAction Stop
        $Config.Email.Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Config.Email.Username, $securePassword
    }
    catch {
        Write-Warning "Failed to load email credentials: $_"
        $Config.Email.Enabled = $false
    }
}

# Initialize log file path
$LogFile = Join-Path -Path $Config.Logging.LogPath -ChildPath $Config.Logging.LogName
#endregion

#region Functions
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$LogFile = $script:LogFile
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
        default { Write-Host $logEntry }
    }
}

function Send-StatusEmail {
    param(
        [string]$Subject,
        [string]$Body,
        [bool]$IsCritical = $false
    )
    
    if (-not $Config.Email.Enabled) {
        return
    }
    
    try {
        $mailParams = @{
            From       = $Config.Email.From
            To         = $Config.Email.To
            Subject    = "$($Config.Email.SubjectPrefix) $Subject"
            Body       = $Body
            SmtpServer = $Config.Email.SmtpServer
            Port       = $Config.Email.SmtpPort
            Credential = $Config.Email.Credential
            Priority   = if ($IsCritical) { "High" } else { "Normal" }
            UseSsl     = $true
        }
        
        Send-MailMessage @mailParams -ErrorAction Stop
        Write-Log "Sent status email with subject: $Subject"
    }
    catch {
        Write-Log "Failed to send email: $_" -Level "ERROR"
    }
}

function Get-ServiceStatus {
    param(
        [string[]]$ServiceNames,
        [string]$ComputerName = $Config.ServerName
    )
    
    try {
        $services = Get-Service -ComputerName $ComputerName -Name $ServiceNames -ErrorAction Stop | 
                    Select-Object Name, DisplayName, Status, StartType, DependentServices, RequiredServices
        
        Write-Log "Successfully retrieved status for $($services.Count) services"
        return $services
    }
    catch {
        Write-Log "Failed to get service status: $_" -Level "ERROR"
        return $null
    }
}

function Start-ServiceWithRetry {
    param(
        [string]$ServiceName,
        [string]$ComputerName = $Config.ServerName,
        [int]$MaxAttempts = $Config.Recovery.MaxRestartAttempts,
        [int]$DelaySeconds = $Config.Recovery.DelayBetweenAttempts
    )
    
    $attempt = 1
    $success = $false
    
    while ($attempt -le $MaxAttempts -and -not $success) {
        try {
            Write-Log "Attempt $attempt to start service $ServiceName on $ComputerName"
            
            $service = Get-Service -ComputerName $ComputerName -Name $ServiceName -ErrorAction Stop
            
            if ($service.Status -ne 'Running') {
                Start-Service -InputObject $service -ErrorAction Stop
                
                # Verify service started
                Start-Sleep -Seconds 2
                $service.Refresh()
                
                if ($service.Status -eq 'Running') {
                    $success = $true
                    Write-Log "Successfully started service $ServiceName on $ComputerName"
                } else {
                    Write-Log "Service $ServiceName still not running after attempt $attempt" -Level "WARN"
                }
            } else {
                $success = $true
                Write-Log "Service $ServiceName is already running on $ComputerName"
            }
        }
        catch {
            Write-Log "Failed to start service $ServiceName (attempt $attempt): $_" -Level "ERROR"
        }
        
        if (-not $success -and $attempt -lt $MaxAttempts) {
            Start-Sleep -Seconds $DelaySeconds
        }
        
        $attempt++
    }
    
    return $success
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
Write-Log "Starting service monitoring for $($Config.ClientName) on server $($Config.ServerName)"

# Rotate log file if needed
if ($Config.Logging.Enabled) {
    Rotate-LogFile -LogPath $Config.Logging.LogPath -LogName $Config.Logging.LogName `
                   -MaxSizeMB $Config.Logging.MaxLogSizeMB -MaxAgeDays $Config.Logging.MaxLogAgeDays
}

# Get current service status
$services = Get-ServiceStatus -ServiceNames $Config.ServicesToMonitor -ComputerName $Config.ServerName

if (-not $services) {
    $errorMsg = "Failed to retrieve service status from $($Config.ServerName)"
    Write-Log $errorMsg -Level "ERROR"
    Send-StatusEmail -Subject "Service Status Check Failed - $($Config.ClientName)" -Body $errorMsg -IsCritical $true
    exit 1
}

# Check for stopped services
$stoppedServices = $services | Where-Object { $_.Status -eq 'Stopped' }

if ($stoppedServices) {
    $stoppedCount = $stoppedServices.Count
    Write-Log "Found $stoppedCount stopped services" -Level "WARN"
    
    # Prepare email body
    $emailBody = @"
The following services were found stopped on server $($Config.ServerName) for $($Config.ClientName):

$(($stoppedServices | Format-Table -Property Name, DisplayName, Status | Out-String))

Server: $($Config.ServerName)
Time: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@
    
    # Send alert email
    Send-StatusEmail -Subject "Stopped Services Alert - $($Config.ClientName)" -Body $emailBody -IsCritical $true
    
    # Attempt to restart stopped services if configured
    if ($Config.Recovery.AttemptRestart) {
        $restartResults = @()
        
        foreach ($service in $stoppedServices) {
            $success = Start-ServiceWithRetry -ServiceName $service.Name -ComputerName $Config.ServerName
            
            $restartResults += [PSCustomObject]@{
                ServiceName = $service.Name
                DisplayName = $service.DisplayName
                RestartSuccess = $success
            }
        }
        
        # Send follow-up email with restart results
        $restartBody = @"
Service Restart Attempt Results:

$(($restartResults | Format-Table -Property ServiceName, DisplayName, @{Name='Status';Expression={if($_.RestartSuccess){'Restarted'}else{'Failed'}}} | Out-String))

Server: $($Config.ServerName)
Time: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@
        
        Send-StatusEmail -Subject "Service Restart Results - $($Config.ClientName)" -Body $restartBody
    }
} else {
    Write-Log "All monitored services are running normally"
}

Write-Log "Service monitoring completed"
#endregion
