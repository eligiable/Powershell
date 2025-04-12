<#
.SYNOPSIS
    Monitors log files for errors, sends alerts, and performs maintenance tasks.
.DESCRIPTION
    Checks log files for specific error patterns, sends email alerts when found,
    restarts affected websites, and archives log files with timestamp.
.NOTES
    File Name      : LogMonitor.ps1
    Author         : Your Name
    Prerequisite   : PowerShell 5.1+, WebAdministration module
#>

# Configuration Parameters
$Config = @{
    LogPath          = "C:\tmp\File_Name.txt"
    ArchivePath      = "C:\tmp\tmp-match\"
    MergedFileName   = "_File_Name.txt"
    WebsiteName      = "Website_Name"
    ErrorPatterns    = @("The operation has timed out", "The underlying provider failed on Open.EntityFramework", "Timeout expired")
    SearchPatterns   = @{
        IDS  = "=== IDS ==="
        TYPE = "=== TYPE ==="
    }
}

# Email Configuration
$EmailConfig = @{
    From        = "alert@example.com"
    To          = "it-support@example.com"
    Cc          = "backup-support@example.com"
    SMTPServer  = "mail.example.com"
    SMTPPort    = 587
    Username    = "alert@example.com"
    Credential  = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username, (Get-Content -Path "C:\security\string.txt" | ConvertTo-SecureString)
    Priority    = "High"
    BodyAsHtml  = $true
}

# Function to extract text between markers
function Get-TextBetweenMarkers {
    param(
        [string]$FirstString,
        [string]$SecondString,
        [string]$FilePath
    )
    
    try {
        $content = Get-Content -Path $FilePath -Raw -ErrorAction Stop
        $pattern = [regex]::Escape($FirstString) + '(.*?)' + [regex]::Escape($SecondString)
        return ([regex]::Match($content, $pattern).Groups[1].Value.Trim()
    }
    catch {
        Write-Warning "Failed to extract text between markers: $_"
        return "[EXTRACTION ERROR]"
    }
}

# Main script execution
try {
    # Check if log file exists
    if (-not (Test-Path -Path $Config.LogPath)) {
        throw "Log file not found at $($Config.LogPath)"
    }

    # Check for errors in log file
    $errorLines = Select-String -Path $Config.LogPath -Pattern $Config.ErrorPatterns -CaseSensitive
    $hasErrors = $null -ne $errorLines

    if ($hasErrors) {
        # Prepare email content
        $errorDetails = $errorLines | ForEach-Object {
            [PSCustomObject]@{
                LineNumber = $_.LineNumber
                LineText   = $_.Line
                Pattern    = $_.Pattern
            }
        }

        # Get additional context from log file
        $contextInfo = Get-TextBetweenMarkers -FirstString $Config.SearchPatterns.IDS -SecondString $Config.SearchPatterns.TYPE -FilePath $Config.LogPath

        # Create HTML email body
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
<h2 class='warning'>⚠️ Application Error Alert</h2>
<p>Server: <strong>$($env:COMPUTERNAME)</strong></p>
<p>Time: <strong>$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</strong></p>
<p>Context: <strong>$contextInfo</strong></p>
<h3>Error Details:</h3>
$($errorDetails | ConvertTo-Html -Property LineNumber, Pattern, LineText -Fragment)
<br>
<p>Automatic website restart has been attempted.</p>
</body>
</html>
"@

        # Send email alert
        $EmailConfig.Subject = "URGENT: Errors detected in $($Config.LogPath) on $($env:COMPUTERNAME) - $contextInfo"
        Send-MailMessage @EmailConfig -Body $HTMLBody -ErrorAction Stop
        Write-Host "Alert email sent successfully at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

        # Restart website (with retry logic)
        try {
            Import-Module WebAdministration -ErrorAction Stop
            
            $maxRetries = 2
            $retryCount = 0
            $success = $false
            
            do {
                $retryCount++
                try {
                    Write-Host "Attempt $retryCount of $maxRetries to restart website..."
                    Stop-WebSite -Name $Config.WebsiteName -ErrorAction Stop
                    Start-WebSite -Name $Config.WebsiteName -ErrorAction Stop
                    $success = $true
                    Write-Host "Website successfully restarted."
                }
                catch {
                    Write-Warning "Attempt $retryCount failed: $_"
                    if ($retryCount -lt $maxRetries) {
                        Start-Sleep -Seconds 5
                    }
                }
            } while (-not $success -and $retryCount -lt $maxRetries)
            
            if (-not $success) {
                throw "Failed to restart website after $maxRetries attempts"
            }
        }
        catch {
            Write-Error "Website restart failed: $_"
            # Could add additional notification here for restart failure
        }
    }
    else {
        Write-Host "No errors detected in log file at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    }

    # Archive log file
    try {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $archiveName = [io.path]::GetFileNameWithoutExtension($Config.LogPath) + "_$timestamp" + [io.path]::GetExtension($Config.LogPath)
        $archivePath = Join-Path -Path $Config.ArchivePath -ChildPath $archiveName
        
        # Ensure archive directory exists
        if (-not (Test-Path -Path $Config.ArchivePath)) {
            New-Item -ItemType Directory -Path $Config.ArchivePath -Force | Out-Null
        }
        
        Move-Item -Path $Config.LogPath -Destination $archivePath -Force -ErrorAction Stop
        Write-Host "Log file archived to $archivePath"
        
        # Merge archived files (if any exist)
        $filesToMerge = Get-Item -Path (Join-Path -Path $Config.ArchivePath -ChildPath "$([io.path]::GetFileNameWithoutExtension($Config.LogPath))*.txt") -ErrorAction SilentlyContinue
        if ($filesToMerge) {
            Get-Content $filesToMerge.FullName | Add-Content -Path (Join-Path -Path $Config.ArchivePath -ChildPath $Config.MergedFileName) -Force
            Remove-Item -Path $filesToMerge.FullName -Force
            Write-Host "Archived files merged into $($Config.MergedFileName)"
        }
    }
    catch {
        Write-Error "Failed to archive log file: $_"
    }
}
catch {
    Write-Error "Script execution failed: $_"
    # Could add additional error notification here
}
