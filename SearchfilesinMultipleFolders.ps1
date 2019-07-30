#Files and Folders to Check
$fileToLocate = "*"
$SearchIn = @(
"C:\Folder_Name_1\",
"C:\Folder_Name_2\",
"C:\Folder_Name_3\"
)

$Max_mins = "-5"
$Curr_date = get-date
$SearchIn = Get-ChildItem -Path $SearchIn | Where{$_.CreationTime -lt ($Curr_date).addminutes($Max_mins)}

#Email Param
$username = "alert@example.com"
$password = Get-Content C:\security\string.txt | ConvertTo-SecureString
$cred = new-object -typename System.Management.Automation.PSCredential ` -argumentlist $username, $password
$localIpAddress = $(ipconfig | where {$_ -match 'IPv4.+\s(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})' } | out-null; $Matches[1])
[string]$messagebody =""
[string]$titlefailed ="Urgent You Have Files in Folder in $localIpAddress in $env:computername"
$portno = "587"
$smtpsrv = "mail.example.com"
$smtpto = "it-support@example.com"
$smtpfrom ="alert@example.com"

if ($SearchIn.Count) {
    foreach ($file in $SearchIn) {[string]$messagebody += $file.FullName + "`r`n"}
    Send-MailMessage -To $smtpto -From $smtpfrom -port $portno -SmtpServer $smtpsrv  -Credential $cred -Subject $titlefailed -Body $messagebody    
}
