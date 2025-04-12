<#
.SYNOPSIS
    Avaya IP Office SMDR Logging and Database Insertion Script
.DESCRIPTION
    This script connects to Avaya IP Office SMDR feed, logs call data to files,
    and optionally inserts records into a MySQL database with enhanced error handling.
.NOTES
    File Name      : AvayaSMDROptimized.ps1
    Author         : Your Name
    Prerequisite   : PowerShell 5.1+, MySQL Connector/NET
    Version        : 2.0
#>

#region Configuration Parameters
# Avaya IP Office SMDR Configuration
# Note: SMDR IP Address MUST be set to 0.0.0.0 in IP Office Administrator
$SMDRConfig = @{
    Host = "172.31.1.8"
    Port = 33333
    ConnectionTimeout = 30000 # 30 seconds in milliseconds
    ReconnectInterval = 60    # Seconds to wait before reconnecting
}

# Logging Configuration
$LogConfig = @{
    Directory = "D:\Call-Logs"
    CallLogPrefix = "calls"
    ErrorLogPrefix = "error"
    MaxLogAge = 30 # Days to keep log files
    LogRotationSizeMB = 50 # Rotate logs when they reach this size
}

# Database Configuration
$DBConfig = @{
    Enabled = $true
    Server = "localhost"
    User = "root"
    Password = "Password" # Consider using encrypted credentials
    Database = "call_logs"
    ConnectionTimeout = 15 # Seconds
    CommandTimeout = 30    # Seconds
    BulkInsertThreshold = 50 # Number of records to batch insert
}

# Email Notification Configuration
$EmailConfig = @{
    Enabled = $true
    From = "alert@example.com"
    To = "it-support@example.com"
    SmtpHost = "mail.example.com"
    SmtpPort = 587
    Username = "alert@example.com"
    PasswordFile = "D:\Call-Logs\Script\securestring.txt"
    ThrottleMinutes = 30 # Minimum minutes between repeat error emails
}
#endregion

#region Initialization
# Load required assemblies
try {
    Add-Type -Path "C:\Program Files (x86)\MySQL\MySQL Connector Net 6.7.8\Assemblies\v2.0\MySql.Data.dll" -ErrorAction Stop
}
catch {
    Write-Error "Failed to load MySQL Data DLL: $_"
    exit 1
}

# Create log directory if it doesn't exist
if (-not (Test-Path -Path $LogConfig.Directory)) {
    try {
        New-Item -ItemType Directory -Path $LogConfig.Directory -Force -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Error "Failed to create log directory: $_"
        exit 1
    }
}

# Initialize email credentials
if ($EmailConfig.Enabled) {
    try {
        $EmailConfig.Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $EmailConfig.Username, (Get-Content $EmailConfig.PasswordFile | ConvertTo-SecureString)
    }
    catch {
        Write-Warning "Failed to load email credentials: $_. Email notifications will be disabled."
        $EmailConfig.Enabled = $false
    }
}

# Database connection string
$DBConfig.ConnectionString = "server=$($DBConfig.Server);uid=$($DBConfig.User);pwd=$($DBConfig.Password);database=$($DBConfig.Database);ConnectionTimeout=$($DBConfig.ConnectionTimeout);CommandTimeout=$($DBConfig.CommandTimeout);"

# Initialize last error time for email throttling
$script:LastErrorEmailTime = $null
#endregion

#region Functions
function Write-Log {
    param(
        [string]$Message,
        [string]$LogType = "Info",
        [string]$LogName = "Application"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$LogType] $Message"
    
    try {
        # Write to appropriate log file
        $today = Get-Date -Format "yyyy-MM-d"
        $logFile = if ($LogType -eq "Error") { 
            "$($LogConfig.Directory)\$($LogConfig.ErrorLogPrefix)-$today.log" 
        } else { 
            "$($LogConfig.Directory)\$($LogConfig.CallLogPrefix)-$today.log" 
        }
        
        $logEntry | Out-File -FilePath $logFile -Append -Encoding UTF8
        
        # Also write to console
        Write-Host $logEntry
    }
    catch {
        Write-Warning "Failed to write to log file: $_"
    }
}

function Notify-Failure {
    param(
        [string]$ErrorMessage,
        [string]$FailedItem,
        [string]$Command,
        [bool]$IsCritical = $false
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $fullMessage = "[$timestamp] - Critical Error on $FailedItem`nError: $ErrorMessage`nFailed Command: $Command"
    
    Write-Log -Message $fullMessage -LogType "Error"
    
    # Send email notification if enabled and not throttled
    if ($EmailConfig.Enabled -and ($IsCritical -or (-not $script:LastErrorEmailTime -or (New-TimeSpan -Start $script:LastErrorEmailTime -End (Get-Date)).TotalMinutes -ge $EmailConfig.ThrottleMinutes))) {
        try {
            $mailParams = @{
                To         = $EmailConfig.To
                From       = $EmailConfig.From
                Port       = $EmailConfig.SmtpPort
                SmtpServer = $EmailConfig.SmtpHost
                Credential = $EmailConfig.Credential
                Subject    = if ($IsCritical) { "CRITICAL: SMDR Logger Failure" } else { "SMDR Logger Error" }
                Body       = $fullMessage
                Priority   = if ($IsCritical) { "High" } else { "Normal" }
            }
            
            Send-MailMessage @mailParams -ErrorAction Stop
            $script:LastErrorEmailTime = Get-Date
            Write-Log "Sent failure notification email"
        }
        catch {
            Write-Log "Failed to send error email: $_" -LogType "Error"
        }
    }
}

function Initialize-DatabaseConnection {
    try {
        $connection = New-Object MySql.Data.MySqlClient.MySqlConnection
        $connection.ConnectionString = $DBConfig.ConnectionString
        $connection.Open()
        
        # Test the connection with a simple query
        $testCommand = $connection.CreateCommand()
        $testCommand.CommandText = "SELECT 1"
        $null = $testCommand.ExecuteScalar()
        $testCommand.Dispose()
        
        return $connection
    }
    catch {
        Notify-Failure -ErrorMessage $_.Exception.Message -FailedItem "Database Connection" -Command "Connection.Open()" -IsCritical $true
        return $null
    }
}

function Invoke-BulkInsert {
    param(
        [MySql.Data.MySqlClient.MySqlConnection]$Connection,
        [System.Collections.Generic.List[string]]$CallRecords
    )
    
    if ($CallRecords.Count -eq 0) {
        return
    }
    
    # Build the bulk insert query
    $query = "INSERT INTO logs (CallStart, ConnectedTime, RingTime, Caller, Direction, CalledNumber, DialledNumber, Account, IsInternal, CallID, Continuation, Party1Device, Party1Name, Party2Device, Party2Name, HoldTime, ParkTime, AuthValid, AuthCode, UserCharged, CallCharge, Currency, AmmountAtLastUserCharge, CallUnits, UnitsAtLastUserCharge, CostPerUnit, MarkUp, ExternalTargettingCause, ExternalTargeterID, ExternalTargetedNumber) VALUES "
    
    $valueClauses = @()
    foreach ($record in $CallRecords) {
        $items = $record.Split(',')
        $values = @(
            "'$($items[0])'", "'$($items[1])'", $($items[2]), "'$($items[3])'", "'$($items[4])'", 
            "'$($items[5])'", "'$($items[6])'", "'$($items[7])'", $($items[8]), $($items[9]), 
            $($items[10]), "'$($items[11])'", "'$($items[12])'", "'$($items[13])'", 
            "'$($items[14])'", $($items[15]), $($items[16]), "'$($items[17])'", 
            "'$($items[18])'", "'$($items[19])'", "'$($items[20])'", "'$($items[21])'", 
            "'$($items[22])'", "'$($items[23])'", "'$($items[24])'", "'$($items[25])'", 
            "'$($items[26])'", "'$($items[27])'", "'$($items[28])'", "'$($items[29])'"
        )
        $valueClauses += "(" + ($values -join ",") + ")"
    }
    
    $query += ($valueClauses -join ",")
    
    try {
        $command = $Connection.CreateCommand()
        $command.CommandText = $query
        $rowsAffected = $command.ExecuteNonQuery()
        Write-Log "Bulk inserted $rowsAffected call records"
        $command.Dispose()
        return $true
    }
    catch {
        Notify-Failure -ErrorMessage $_.Exception.Message -FailedItem "Bulk Insert" -Command $query
        return $false
    }
}

function Rotate-LogFiles {
    param(
        [string]$LogDirectory,
        [string]$LogPrefix,
        [int]$MaxAgeDays,
        [int]$MaxSizeMB
    )
    
    try {
        # Delete old log files
        Get-ChildItem -Path $LogDirectory -Filter "$LogPrefix-*.log" | 
            Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$MaxAgeDays) } | 
            Remove-Item -Force -ErrorAction SilentlyContinue
        
        # Rotate large log files
        Get-ChildItem -Path $LogDirectory -Filter "$LogPrefix-*.log" | 
            Where-Object { $_.Length -gt ($MaxSizeMB * 1MB) } | 
            ForEach-Object {
                $newName = $_.FullName -replace '\.log$', ('-' + (Get-Date -Format 'yyyyMMddHHmmss') + '.log')
                Rename-Item -Path $_.FullName -NewName $newName -Force
            }
    }
    catch {
        Write-Log "Failed to rotate log files: $_" -LogType "Error"
    }
}

function Connect-SMDRStream {
    param(
        [string]$HostName,
        [int]$Port,
        [int]$Timeout
    )
    
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $connectTask = $client.ConnectAsync($HostName, $Port)
        
        if (-not $connectTask.Wait($Timeout)) {
            throw "Connection timed out after $Timeout ms"
        }
        
        if (-not $client.Connected) {
            throw "Failed to connect to SMDR host"
        }
        
        $stream = $client.GetStream()
        Write-Log "Connected to SMDR Host: $HostName on port $Port"
        return @{
            Client = $client
            Stream = $stream
        }
    }
    catch {
        Notify-Failure -ErrorMessage $_.Exception.Message -FailedItem "SMDR Connection" -Command "TcpClient.Connect($HostName, $Port)" -IsCritical $true
        return $null
    }
}
#endregion

#region Main Script Execution
Write-Log "Starting Avaya SMDR Logger"

# Initialize buffer and encoding
$buffer = New-Object byte[] 4096
$encoding = [System.Text.Encoding]::ASCII
$pendingRecords = [System.Collections.Generic.List[string]]::new()

# Main processing loop
while ($true) {
    $connection = $null
    $smdrConnection = $null
    
    try {
        # Rotate log files daily
        Rotate-LogFiles -LogDirectory $LogConfig.Directory -LogPrefix $LogConfig.CallLogPrefix -MaxAgeDays $LogConfig.MaxLogAge -MaxSizeMB $LogConfig.LogRotationSizeMB
        Rotate-LogFiles -LogDirectory $LogConfig.Directory -LogPrefix $LogConfig.ErrorLogPrefix -MaxAgeDays $LogConfig.MaxLogAge -MaxSizeMB $LogConfig.LogRotationSizeMB
        
        # Connect to SMDR
        $smdrConnection = Connect-SMDRStream -HostName $SMDRConfig.Host -Port $SMDRConfig.Port -Timeout $SMDRConfig.ConnectionTimeout
        if (-not $smdrConnection) {
            Write-Log "Waiting $($SMDRConfig.ReconnectInterval) seconds before reconnecting..."
            Start-Sleep -Seconds $SMDRConfig.ReconnectInterval
            continue
        }
        
        # Connect to database if enabled
        if ($DBConfig.Enabled) {
            $connection = Initialize-DatabaseConnection
            if (-not $connection) {
                Write-Log "Waiting 60 seconds before retrying database connection..."
                Start-Sleep -Seconds 60
                continue
            }
        }
        
        # Process SMDR stream
        while ($true) {
            # Check for new data with a read timeout
            if ($smdrConnection.Client.Available -gt 0) {
                $bytesRead = $smdrConnection.Stream.Read($buffer, 0, $buffer.Length)
                if ($bytesRead -gt 0) {
                    $data = $encoding.GetString($buffer, 0, $bytesRead)
                    
                    # Split into individual call records
                    $lines = $data.Split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)
                    
                    foreach ($line in $lines) {
                        if (-not [string]::IsNullOrWhiteSpace($line)) {
                            # Log to file
                            $today = Get-Date -Format "yyyy-MM-d"
                            $line | Out-File "$($LogConfig.Directory)\$($LogConfig.CallLogPrefix)-$today.log" -Append -Encoding UTF8
                            
                            # Add to pending records for database insertion
                            if ($DBConfig.Enabled) {
                                $pendingRecords.Add($line)
                                
                                # Bulk insert when threshold is reached
                                if ($pendingRecords.Count -ge $DBConfig.BulkInsertThreshold) {
                                    if (Invoke-BulkInsert -Connection $connection -CallRecords $pendingRecords) {
                                        $pendingRecords.Clear()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            # Insert any remaining records if we haven't reached the threshold
            if ($DBConfig.Enabled -and $pendingRecords.Count -gt 0 -and $connection) {
                if (Invoke-BulkInsert -Connection $connection -CallRecords $pendingRecords) {
                    $pendingRecords.Clear()
                }
            }
            
            # Small sleep to prevent CPU overload
            Start-Sleep -Milliseconds 100
        }
    }
    catch [System.IO.IOException] {
        Notify-Failure -ErrorMessage $_.Exception.Message -FailedItem "SMDR Stream" -Command "Stream.Read()"
    }
    catch {
        Notify-Failure -ErrorMessage $_.Exception.Message -FailedItem "Main Processing Loop" -Command "Unknown" -IsCritical $true
    }
    finally {
        # Clean up resources
        if ($connection) {
            try {
                $connection.Close()
                $connection.Dispose()
                Write-Log "Closed database connection"
            }
            catch {
                Write-Log "Error closing database connection: $_" -LogType "Error"
            }
        }
        
        if ($smdrConnection) {
            try {
                $smdrConnection.Stream.Dispose()
                $smdrConnection.Client.Dispose()
                Write-Log "Closed SMDR connection"
            }
            catch {
                Write-Log "Error closing SMDR connection: $_" -LogType "Error"
            }
        }
        
        # If we're here, we lost connection - wait before reconnecting
        if ($connection -or $smdrConnection) {
            Write-Log "Waiting $($SMDRConfig.ReconnectInterval) seconds before reconnecting..."
            Start-Sleep -Seconds $SMDRConfig.ReconnectInterval
        }
    }
}
#endregion
