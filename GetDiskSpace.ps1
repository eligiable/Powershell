$Client="Name_TO_Represent_THE_Server"

#Email Params
$From = "alert@example.com"
        $To = "it-support@example.com"
        $SMTPServer = "mail.example.com"
        $SMTPPort = "587"
        $Username = "alert@example.com"
        $Password = Get-Content C:\security\string.txt | ConvertTo-SecureString
        $Subject = " Urgent Disk Space is Low in $Client $($env:computername) " 
        $Cred = new-object -typename System.Management.Automation.PSCredential `
                -argumentlist $username, $password

#Get Disk Size
$Size = Get-WmiObject win32_logicaldisk -Filter "Drivetype=3" | Where-Object { ($_.freespace/$_.size) -le '0.1'} |
ft DeviceID,@{Label = " Free Space(%) "; Expression = {"{0:P0}" -f ($_.freespace/$_.size)}}, @{Label = " Total SIze(GB) "; Expression = {$_.Size / 1gb -as [int] }}, @{Label = " Free Size(GB) "; Expression = {$_.freespace / 1gb -as [int] }} -autosize | Out-String

#Send Email
if ($Size){
	Send-MailMessage -To $To -From $From -port $SMTPPort -SmtpServer $SMTPServer  -Credential $Cred  -Subject $Subject -Body $Size
}
