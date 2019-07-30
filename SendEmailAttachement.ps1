#Folders to Check
$fileToLocate = "*"
$SearchIn = @(
"D:\Folder_Name_1",
"D:\Folder_Name_2",
"D:\Folder_Name_3"
)

#File Attachements and Date
$file_attachments = @()
$SearchIn = Get-ChildItem -Path $SearchIn | Where { ($_.LastWriteTime -ge [datetime]::Now.AddDays(-1) ) }

#Email Param
$username = "alert@example.com"
$password = Get-Content C:\security\string.txt | ConvertTo-SecureString
$cred = new-object -typename System.Management.Automation.PSCredential ` -argumentlist $username, $password
$localIpAddress = $(ipconfig | where {$_ -match 'IPv4.+\s(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})' } | out-null; $Matches[1])
[string]$messagebody =""
[string]$titlesent ="Attached Files are added today @ .189"
$portno = "587"
$smtpsrv = "mail.example.com"
$smtpto = "it-support@example.com"
$smtpfrom ="alert@example.com"

if ($SearchIn.Count) {
  foreach ($file in $SearchIn) {[string]$messagebody += $file.FullName + "`r`n"}
	foreach ($file in $SearchIn) {$file_attachments += $file.FullName}
  Send-MailMessage -To $smtpto -From $smtpfrom -port $portno -SmtpServer $smtpsrv -Credential $cred -Subject $titlesent -Body $messagebody -Attachments $file_attachments 
}

