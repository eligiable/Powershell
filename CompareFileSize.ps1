#Compare Files
$username = "alert@example.com"
$password = Get-Content C:\security\string.txt | ConvertTo-SecureString
$cred = new-object -typename System.Management.Automation.PSCredential ` -argumentlist $username, $password

$LastFilestoCheck = Get-ChildItem -Path "C:\tmp-match\"
$CurrentFilestoCheck = Get-ChildItem -Path "C:\tmp\Folder_Name\" -Filter *.txt | Where-Object {$_.LastWriteTime -ge (Get-Date).Date}

Compare-Object -ReferenceObject $LastFilestoCheck -DifferenceObject $CurrentFilestoCheck -Property Name,LastWriteTime -IncludeEqual | %{

    if ($_.SideIndicator -eq "==")
    {
        [string]$messagebody ="It seems that Files are not changed in previous 5 Minutes, kindly check the below files for today's date:`n`n"
        [string]$titlesent ="Files are not changed since 5 Minutes"
        $portno = "587"
        $smtpsrv = "mail.example.com"
        $smtpto = "it-support@example.com", "someoneelse@example.com"
        $smtpfrom = "alert@example.com"

        if ($CurrentFilestoCheck.Count) {
	        foreach ($file in $CurrentFilestoCheck) {[string]$messagebody += $file.FullName + "`r`n"}
            Send-MailMessage -To $smtpto -From $smtpfrom -port $portno -SmtpServer $smtpsrv -Credential $cred -Subject $titlesent -Body $messagebody 
        }
    }
}
#Delete Existing Files
Remove-Item –path "C:\tmp-match\*"

#Copy Files to be checked after
$FilestoCopy = Get-ChildItem -Path "C:\tmp\Folder_Name\" -Filter *.txt | Where-Object {$_.LastWriteTime -ge (Get-Date).Date}
$FilesDestination = "C:\tmp-match\"
Copy-Item $FilestoCopy.FullName -Destination $FilesDestination

#Restart Service
Clear-Host
Get-Process Service_Name | Stop-Process -Force

timeout /T 10
Start-Service Service_Name
