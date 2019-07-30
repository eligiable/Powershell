# Sync folders to S3 using Powershell
# 1. Install free Cloudberry Explorer for S3
# 2. Create folder(s) on S3 ahead of time for data -- you do this once
# 3. Replace ALLCAPS with your values
# 4. Create SyncFolder line(s) below with your values (see example)
# 5. Uncomment rrs line if you want to use reduced redundancy storage (optional)

add-pssnapin CloudBerryLab.Explorer.PSSnapIn
$s3 = Get-CloudS3Connection -Key YOURAWSKEY -Secret YOURAWSSECRET
$local = Get-CloudFilesystemConnection
$bucket = "BUCKETNAME"

function SyncFolder ($localfoldername, $remotefoldername)
{
$source = $local | Select-CloudFolder $localfoldername
$s3folder = $bucket + $remotefoldername
$target = $s3 | Select-CloudFolder -Path $s3folder
$source | Copy-CloudSyncFolders $target -IncludeSubFolders -DeleteOnTarget
# Uncomment next line if you want to use reduced redundancy storage
# $target | Set-CloudStorageClass -StorageClass rrs
return $localfoldername
}

# Use below format to sync folders
# $foldertoSync = SyncFolder ($localfoldername, $remotefoldername)/
$folderstoSync = @(
SyncFolder "C:\Script" "/Script"
SyncFolder "C:\security" "/security"
SyncFolder "C:\inetpub\wwwroot" "/inetpub/wwwroot"
SyncFolder "C:\tmp" "/tmp"
)

$Max_mins = "-5"
$Curr_date = get-date
$username = "alert@example.com"
$password = Get-Content C:\security\string.txt | ConvertTo-SecureString
$cred = new-object -typename System.Management.Automation.PSCredential ` -argumentlist $username, $password
$filesSynced = Get-ChildItem -Path $folderstoSync  | Where{$_.CreationTime -lt ($Curr_date).addminutes($Max_mins)}
[string]$messagebody =""
[string]$titlefailed ="S3Sync from SERVERNAME @ IP"
$portno = "587"
$smtpsrv = "mail.example.com"
$smtpto = "it-support@example.com"
$smtpfrom ="alert@example.com"
 
if ($filesSynced.Count) {
    foreach ($file in $filesSynced) {[string]$messagebody += $file.FullName + "`r`n"}
    Send-MailMessage -To $smtpto -From $smtpfrom -port $portno -SmtpServer $smtpsrv  -Credential $cred -Subject $titlefailed -Body $messagebody    
}

