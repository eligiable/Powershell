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
