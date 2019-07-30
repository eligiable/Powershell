#Get the List of Files in the Source Folder
$rootFolder = "C:\tmp"
$tempVariable = $rootFolder
$files = Get-ChildItem -Path $rootFolder 

#Create a Temporary Folder for Today's Date
$tempFolderRoot = "C:\Temp_"
$date = Get-Date
$date = $date.ToString("yyyy-MM-dd")
$tempFinalFolder = "$tempFolderRoot$date"
New-Item -ItemType directory -Path $tempFinalFolder -Force

#Days to Archive_
$timespan = new-timespan -days 30

#Move Files to Temporary Location
foreach($file in $files)
{
	$fileLastModifieddate = $file.LastWriteTime
	if(((Get-Date) - $fileLastModifiedDate) -gt $timespan)
	{
		Move-Item "$rootFolder\$file" -destination $tempFinalFolder
	}
}

$CompressionToUse = [System.IO.Compression.CompressionLevel]::Optimal
$IncludeBaseFolder = $false
$zipTo = "{0}\Archive-{1}.zip" -f $rootFolder,$date

#Compress the Files to ZIP
[Reflection.Assembly]::LoadWithPartialName( "System.IO.Compression.FileSystem" )
[System.IO.Compression.ZipFile]::CreateFromDirectory($tempFinalFolder, $ZipTo, $CompressionToUse, $IncludeBaseFolder)

#Remove Temporary Location
Remove-Item $tempFinalFolder -RECURSE

#Move ZIP Archive to Network Path
Move-Item $zipTo -destination "\\Network_PATH"

#---------------------------------------------------------------------------------------------------------------------------------------

#Folder Path to Check
$SuccessPath = "C:\Folder_Name\*.*"

#Get Date and Number of Days
$Max_days = "-30"
$Curr_date = get-date
$files = Get-ChildItem -Path $SuccessPath | Where{$_.LastWriteTime -lt ($Curr_date).AddDays($Max_days)}

#Email Param
$username = "alert@example.com"
$password = Get-Content C:\security\string.txt | ConvertTo-SecureString
$cred = new-object -typename System.Management.Automation.PSCredential ` -argumentlist $username, $password
$localIpAddress = $(ipconfig | where {$_ -match 'IPv4.+\s(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})' } | out-null; $Matches[1])
[string]$messagebody =""
[string]$title ="Success TransActions been Archived for more than 30 days in $localIpAddress in $env:computername"
$portno = "587"
$smtpsrv = "mail.example.com"
$smtpto = "it-support@example.com"
$smtpfrom ="alert@example.com"

#Destination to Move the Files
$dest = "\\Network_PATH"

if ($files.Count) {
    Move-Item -path $files -Destination $dest
    foreach ($file in $files) {[string]$messagebody += $file.Name + "`r`n"}
    Send-MailMessage -To $smtpto -From $smtpfrom -port $portno -SmtpServer $smtpsrv -Credential $cred -Subject $title -Body $messagebody
}

    
