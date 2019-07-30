$(
$AE = "D:\Folder_Name\AE"

$ftp = "ftp://FTP_Address/AE/" 
$user = "Username"
$pass = "Password"

$webclient = New-Object System.Net.WebClient 
 
$webclient.Credentials = New-Object System.Net.NetworkCredential($user,$pass)

foreach($item in (dir $AE "*")){ 
    "Uploading $item..." 
    $uri = New-Object System.Uri($ftp+$item.Name) 
    $webclient.UploadFile($uri, $item.FullName) 
 }
) *>&1 > C:\Script\UploadtoFTP.txt
$(
$BH = "D:\Folder_Name\BH"

$ftp = "ftp://FTP_Address/BH/" 
$user = "Username"
$pass = "Password"

$webclient = New-Object System.Net.WebClient 
 
$webclient.Credentials = New-Object System.Net.NetworkCredential($user,$pass)

foreach($item in (dir $BH "*")){ 
    "Uploading $item..." 
    $uri = New-Object System.Uri($ftp+$item.Name) 
    $webclient.UploadFile($uri, $item.FullName) 
 }
) *>&1 > C:\Script\UploadtoFTP.txt
$(
$KW = "D:\Folder_Name\KW"

$ftp = "ftp://FTP_Address/KW/" 
$user = "Username"
$pass = "Password"

$webclient = New-Object System.Net.WebClient 
 
$webclient.Credentials = New-Object System.Net.NetworkCredential($user,$pass)

foreach($item in (dir $KW "*")){ 
    "Uploading $item..." 
    $uri = New-Object System.Uri($ftp+$item.Name) 
    $webclient.UploadFile($uri, $item.FullName) 
 }
) *>&1 > C:\Script\UploadtoFTP.txt
$(
$OM = "D:\Folder_Name\OM"

$ftp = "ftp://FTP_Address/OM/" 
$user = "Username"
$pass = "Password"

$webclient = New-Object System.Net.WebClient 
 
$webclient.Credentials = New-Object System.Net.NetworkCredential($user,$pass)

foreach($item in (dir $OM "*")){ 
    "Uploading $item..." 
    $uri = New-Object System.Uri($ftp+$item.Name) 
    $webclient.UploadFile($uri, $item.FullName) 
 }
) *>&1 > C:\Script\UploadtoFTP.txt
$(
$SA = "D:\Folder_Name\SA"

$ftp = "ftp://FTP_Address/SA/" 
$user = "Username"
$pass = "Password"

$webclient = New-Object System.Net.WebClient 
 
$webclient.Credentials = New-Object System.Net.NetworkCredential($user,$pass)

foreach($item in (dir $SA "*")){ 
    "Uploading $item..." 
    $uri = New-Object System.Uri($ftp+$item.Name) 
    $webclient.UploadFile($uri, $item.FullName) 
 }
) *>&1 > C:\Script\UploadtoFTP.txt
$(
$SA2 = "D:\Folder_Name\SA2"

$ftp = "ftp://FTP_Address/SA2/" 
$user = "Username"
$pass = "Password"

$webclient = New-Object System.Net.WebClient 
 
$webclient.Credentials = New-Object System.Net.NetworkCredential($user,$pass)

foreach($item in (dir $SA2 "*")){ 
    "Uploading $item..." 
    $uri = New-Object System.Uri($ftp+$item.Name) 
    $webclient.UploadFile($uri, $item.FullName) 
 }
) *>&1 > C:\Script\UploadtoFTP.txt
