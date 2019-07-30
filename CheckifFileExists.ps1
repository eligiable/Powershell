#Folder to Check
$inboundPath = "C:\Folder_Name\*.xml"

$Max_mins = "-5"
$Curr_date = get-date
$files = Get-ChildItem -Path $inboundPath | Where{$_.LastWriteTime -gt ($Curr_date).addminutes($Max_mins)}
$servicelogsrc = "C:\tmp\FileInspectorLog.txt"
$servicelogdest = "C:\fileinsplog\FileInspectorLog.txt"

$ServiceName = "Service_Name"

#Email Param
$username = "alert@example.com"
$password = cat C:\security\string.txt | convertto-securestring
$cred = new-object -typename System.Management.Automation.PSCredential `
         -argumentlist $username, $password
$portno = "587"
$smtpsrv = "mail.example.com"
$smtpto = "it-support@example.com"
$smtpfrom ="alert@example.com"
$localIpAddress = $(ipconfig | where {$_ -match 'IPv4.+\s(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})' } | out-null; $Matches[1])
[string]$messagebody =""
[string]$title ="Urgent You Have Files in Inbound Folder in $localIpAddress in $env:computername"

if ($files.Count){
  Copy-Item -Path $servicelogsrc -Destination $servicelogdest
  Restart-Service $ServiceName
  foreach ($file in $files) {[string]$messagebody += $file.Name + "`r`n"}
  Send-MailMessage -To $smtpto -From $smtpfrom -port $portno -SmtpServer $smtpsrv  -Credential $cred  -Subject $title -Body $messagebody
}   
