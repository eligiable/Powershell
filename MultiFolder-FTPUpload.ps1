<#
.SYNOPSIS
    Uploads files from local directories to corresponding FTP locations.
.DESCRIPTION
    This script uploads files from multiple local directories to their respective FTP locations.
    It includes error handling, logging, and configuration in a more maintainable format.
.NOTES
    Version: 1.1
    Author: Your Name
    Date: $(Get-Date -Format "yyyy-MM-dd")
#>

# Configuration
$config = @(
    @{
        LocalFolder = "D:\Folder_Name\AE"
        FtpUrl = "ftp://FTP_Address/AE/"
        Username = "Username"
        Password = "Password"
    },
    @{
        LocalFolder = "D:\Folder_Name\BH"
        FtpUrl = "ftp://FTP_Address/BH/"
        Username = "Username"
        Password = "Password"
    },
    @{
        LocalFolder = "D:\Folder_Name\KW"
        FtpUrl = "ftp://FTP_Address/KW/"
        Username = "Username"
        Password = "Password"
    },
    @{
        LocalFolder = "D:\Folder_Name\OM"
        FtpUrl = "ftp://FTP_Address/OM/"
        Username = "Username"
        Password = "Password"
    },
    @{
        LocalFolder = "D:\Folder_Name\SA"
        FtpUrl = "ftp://FTP_Address/SA/"
        Username = "Username"
        Password = "Password"
    },
    @{
        LocalFolder = "D:\Folder_Name\SA2"
        FtpUrl = "ftp://FTP_Address/SA2/"
        Username = "Username"
        Password = "Password"
    }
)

# Log file path
$logFile = "C:\Script\UploadtoFTP_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

# Function to upload files to FTP
function Upload-ToFTP {
    param (
        [string]$localPath,
        [string]$ftpUrl,
        [string]$username,
        [string]$password
    )

    try {
        # Create web client
        $webClient = New-Object System.Net.WebClient
        $webClient.Credentials = New-Object System.Net.NetworkCredential($username, $password)

        # Get files to upload
        $files = Get-ChildItem -Path $localPath -File

        if ($files.Count -eq 0) {
            Write-Output "No files found in $localPath to upload."
            return
        }

        Write-Output "Starting upload of $($files.Count) files from $localPath to $ftpUrl"

        foreach ($file in $files) {
            try {
                $uri = New-Object System.Uri($ftpUrl + $file.Name)
                Write-Output "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Uploading $($file.Name)..."
                
                $webClient.UploadFile($uri, $file.FullName)
                
                Write-Output "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Successfully uploaded $($file.Name)"
            }
            catch {
                Write-Output "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ERROR uploading $($file.Name): $_"
            }
        }
    }
    catch {
        Write-Output "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] FATAL ERROR processing $localPath: $_"
    }
    finally {
        if ($webClient -ne $null) {
            $webClient.Dispose()
        }
    }
}

# Main execution
try {
    # Start logging
    Write-Output "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Starting FTP upload process" | Tee-Object -FilePath $logFile -Append

    # Process each configuration
    foreach ($item in $config) {
        Write-Output "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Processing folder: $($item.LocalFolder)" | Tee-Object -FilePath $logFile -Append
        
        Upload-ToFTP -localPath $item.LocalFolder -ftpUrl $item.FtpUrl -username $item.Username -password $item.Password | Tee-Object -FilePath $logFile -Append
        
        Write-Output "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Completed processing folder: $($item.LocalFolder)" | Tee-Object -FilePath $logFile -Append
        Write-Output "--------------------------------------------------" | Tee-Object -FilePath $logFile -Append
    }

    Write-Output "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] FTP upload process completed" | Tee-Object -FilePath $logFile -Append
}
catch {
    Write-Output "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] SCRIPT ERROR: $_" | Tee-Object -FilePath $logFile -Append
}

# Display completion message
Write-Host "Upload process completed. Log file created at $logFile"
