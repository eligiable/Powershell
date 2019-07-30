$Client="Name_TO_Represent_THE_Server"

#Services to Monitor
$ServiceToMon = @("Service_Name_1", "Service_Name_2") #define service names here
$Serv="A1S2D3F-A1S2D3F" #define server name here

#Email Params
$From = "alert@example.com"
        $To = "it-support@example.com"
        $SMTPServer = "mail.example.com"
        $SMTPPort = "587"
        $Username = "alert@example.com"
        $Password = Get-Content C:\security\string.txt | ConvertTo-SecureString
        $Body = "Start the Service if Found Stopped @ ""$($env:computername)""`n"
        $Subject = " Services Status for $Client $($env:computername) "

#Get Service Status in a Table
$Body += (Get-Service $ServiceToMon| Select Name, DisplayName, Status | Sort Name | Format-List| Out-String)

#Send Email when any Listed Service is Stopped
if(Get-Service -computername $Serv $ServiceToMon  | where {$_.Status -eq 'Stopped'}) {
    $smtp = New-Object System.Net.Mail.SmtpClient($SMTPServer, $SMTPPort);
    $smtp.Credentials = New-Object -typename System.Management.Automation.PSCredential ` -argumentlist $Username, $Password
    $smtp.Send($From, $To, $Subject, $Body);
}

#Start the Services
Get-Service -computername $Serv $ServiceToMon  | where {$_.Status -eq 'Stopped'}  | foreach { $_.start() }
timeout /T 10
