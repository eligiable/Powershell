#Check Error in the Log File
$fail = Get-Content "C:\tmp\File_Name.txt" | Select-String "The operation has timed out" -quiet -casesensitive

#Email Params
$From = "alert@example.com"
$To = "it-support@example.com"
$SMTPServer = "mail.example.com"
$SMTPPort = "587"
$Username = "alert@example.com"
$Password = Get-Content C:\security\string.txt | ConvertTo-SecureString
$Body =  Select-String -Path "C:\tmp\File_Name.txt" -Pattern "The operation has timed out" | Select-Object -ExpandProperty line
$Subject = "ERROR in File_Name on Server .140"

#Send Email when any Listed Service is Stopped
if($fail -eq "True"){
    $smtp = New-Object System.Net.Mail.SmtpClient($SMTPServer, $SMTPPort);
    $smtp.Credentials = New-Object -typename System.Management.Automation.PSCredential ` -argumentlist $Username, $Password
    $smtp.Send($From, $To, $Subject, $Body);
}

#Move File to another Folder
$FileName = Get-Item -Path "C:\tmp\File_Name.txt"
$file   = [io.path]::GetFileNameWithoutExtension($FileName)
$ext    = [io.path]::GetExtension($FileName)
$Destination = "C:\tmp\tmp-match\" + $file + $(get-date -f yyyyMMdd-HHmmss) + $ext
Move-Item $fileName $Destination

#Merge Multiple Files Created
Get-Content C:\tmp\tmp-match\File_Name*.txt | Add-Content C:\tmp\tmp-match\_File_Name.txt

#Remove Multiple Files
Remove-Item –path C:\tmp\tmp-match\File_Name*.txt

#------------------------------------------------------------------------------------------------------------------------------------------

#Get Subject Function
function GetStringBetweenTwoStrings($firstString, $secondString, $importPath){

    #Get content from file
    $file = Get-Content $importPath

    #Regex pattern to compare two strings
    $pattern = "$firstString(.*?)$secondString"

    #Perform the opperation
    $result = [regex]::Match($file,$pattern).Groups[1].Value

    #Return result
    return $result
}

#Check Error in the Log File
$fail = Get-Content "C:\tmp\File_Name.txt" | Select-String "The underlying provider failed on Open.EntityFramework", "Timeout expired" -Quiet -CaseSensitive

#Email Params
$From = "alert@example.com"
$To = "it-support@example.com"
$SMTPServer = "mail.example.com"
$SMTPPort = "587"
$Username = "alert@example.com"
$Password = Get-Content C:\security\string.txt | ConvertTo-SecureString
$Body =  Select-String -Path "C:\tmp\File_Name.txt" -Pattern "The underlying provider failed on Open.EntityFramework", "Timeout expired" | Select-Object -ExpandProperty line
$Sbj1 = "ERROR in File_Name on Server .140"
$Sbj2 = GetStringBetweenTwoStrings -firstString "=== IDS ===" -secondString "=== TYPE ===" -importPath "C:\tmp\File_Name.txt"
$Subject = Write-Output "$($Sbj1) - $($Sbj2)"

#Send Email
if($fail -eq "True"){
    $smtp = New-Object System.Net.Mail.SmtpClient($SMTPServer, $SMTPPort);
    $smtp.Credentials = New-Object -typename System.Management.Automation.PSCredential ` -argumentlist $Username, $Password
    $smtp.Send($From, $To, $Subject, $Body);

    #Restart Website
    Import-Module WebAdministration
    Stop-WebSite -Name "Website_Name"
    Start-WebSite -Name "Website_Name"

    Stop-WebSite -Name "Website_Name"
    Start-WebSite -Name "Website_Name"
}

#Move File to another Folder
$FileName = Get-Item -Path "C:\tmp\File_Name.txt"
$file   = [io.path]::GetFileNameWithoutExtension($FileName)
$ext    = [io.path]::GetExtension($FileName)
$Destination = "C:\tmp\tmp-match\" + $file + $(get-date -f yyyyMMdd-HHmmss) + $ext
Move-Item $fileName $Destination

#Merge Multiple Files Created
Get-Content C:\tmp\tmp-match\File_Name*.txt | Add-Content C:\tmp\tmp-match\_File_Name.txt

#Remove Multiple Files
Remove-Item -path C:\tmp\tmp-match\File_Name*.txt
