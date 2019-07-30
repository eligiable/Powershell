#Folder Path to Delete the Items From
$folderstoDelete = @(
"D:\Folder_Name\"
)

#Days to Delete from the Files Creation Date
Get-ChildItem -Path $folderstoDelete -Recurse -File | Where CreationTime -lt  (Get-Date).AddDays(-30)  | Remove-Item -Force
$Max_mins = "-5"
$Curr_date = get-date

#Email Params
$username = "alert@example.com"
$password = Get-Content C:\security\string.txt | ConvertTo-SecureString
$cred = new-object -typename System.Management.Automation.PSCredential ` -argumentlist $username, $password
$filesDeleted = Get-ChildItem -Path $folderstoDelete  | Where{$_.CreationTime -lt ($Curr_date).addminutes($Max_mins)}
[string]$messagebody =""
[string]$titlefailed ="Cache Cleared from CTV Pilot @ 52.18.254.124"
$portno = "587"
$smtpsrv = "mail.example.com"
$smtpto = "it-support@example.com"
$smtpfrom ="alert@example.com"

if ($filesDeleted.Count) {
    foreach ($file in $filesDeleted) {[string]$messagebody += $file.FullName + "`r`n"}
    Send-MailMessage -To $smtpto -From $smtpfrom -port $portno -SmtpServer $smtpsrv  -Credential $cred -Subject $titlefailed -Body $messagebody    
}
