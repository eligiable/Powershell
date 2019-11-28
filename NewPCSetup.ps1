$source = 'C:\Softwares-for-installation' 
$Credentials = Get-Credential
$TargetPath = 'C:\Softwares-for-installation' 
$ODTPath = "\\172.31.2.20\Backup\SoftPile\WindowsSoftware\Microsoft\Office\ODT"
$Officeinstallationcommand = C:\Softwares-for-installation\ODT\setup.exe /configure installOfficeBusRet64.xml
$7ziprename = "C:\Softwares-for-installation\download"

$User_Floor = Read-Host "Which floor is the user located on? Please enter value from 0 to 2 only."

#Copy files from network share folder to a local folder. 
function CopyFilesfromSourcefolder {
    Write-Host "Creating PsDrive from ServerPath"
    New-PSDrive -Name PsDrive -PSProvider "FileSystem" -Root $ODTPath -Credential $Credentials
    Write-Host "Connection Successful!"
    Copy-Item -Path $ODTPath -Destination $TargetPath -Recurse -force -Verbose       
    Write-Host "Files copied!"
}

#Install Office Application
function Install_Office {
    Write-Host "Installing Office 365"
    $jobinstalloffice = Start-Job -ScriptBlock { Invoke-Command -ScriptBlock { $Officeinstallationcommand } }
    $jobinstalloffice | Wait-Job    
}

#http://dl.google.com/google-apps-sync/googleappssyncsetup.exe

#Download files from the internet
function Download_and_Install_New_Softwares {
    
    If (!(Test-Path -Path $source -PathType Container)) {New-Item -Path $source -ItemType Directory | Out-Null} 

    $packages = @( 
        @{title='Mozilla-Latest';url='https://download-installer.cdn.mozilla.net/pub/firefox/releases/69.0.3/win64/en-US/Firefox%20Setup%2069.0.3.exe';Arguments=' /qn';Destination=$source},
        @{title='VLC-3.0.8';url='https://get.videolan.org/vlc/3.0.8/win32/vlc-3.0.8-win32.exe';Arguments=' /qn';Destination=$source},
        @{title='CC-Cleaner-5.6.2';url='https://download.ccleaner.com/ccsetup562.exe';Arguments=' /qn';Destination=$source},
        @{title='Google FileStream';url='https://dl.google.com/drive-file-stream/GoogleDriveFSSetup.exe';Arguments=' /qn';Destination=$source},
        @{title='Google App Sync';url='https://dl.google.com/tag/s/appguid%3D%7BBEBCAD10-F1BC-4F92-B4A7-9E2545C809ED%7D%26iid%3D%7B1A46AC68-444C-DCE0-84CA-E62E9E982C56%7D%26lang%3Den%26browser%3D4%26usagestats%3D0%26appname%3DG%2520Suite%2520Sync%25E2%2584%25A2%2520for%2520Microsoft%2520Outlook%25C2%25AE%26needsadmin%3Dtrue%26appguid%3D%7B7DF3B6EE-9890-4307-BDE5-E1F3FCB09771%7D%26appname%3DG%2520Suite%2520Migration%25E2%2584%25A2%2520for%2520Microsoft%2520Outlook%25C2%25AE%26needsadmin%3Dtrue/google-apps-sync/googleappssyncsetup.exe';Arguments=' /qn';Destination=$source},
        @{title='RingCentral-Glip';url='http://downloads.ringcentral.com/glip/rc/19.10.2/x64/RingCentral-19.10.2-x64.exe';Arguments=' /qn';Destination=$source},
        @{title='Chrome';url='https://dl.google.com/tag/s/appguid%3D%7B8A69D345-D564-463C-AFF1-A69D9E530F96%7D%26iid%3D%7B76DCB9A5-930D-6451-2DA8-E3B9C79E4218%7D%26lang%3Den%26browser%3D4%26usagestats%3D1%26appname%3DGoogle%2520Chrome%26needsadmin%3Dprefers%26ap%3Dx64-stable-statsdef_1%26installdataindex%3Ddefaultbrowser/update2/installers/ChromeSetup.exe';Arguments=' /qn';Destination=$source},
        @{title='7zip';url='https://sourceforge.net/projects/sevenzip/files/7-Zip/19.00/7z1900-x64.exe/download';Arguments=' /qn';Destination=$source},
        @{title='Owncloud';url='https://download.owncloud.com/desktop/stable/ownCloud-2.5.0.10359-setup.exe';Arguments=' /qn';Destination=$source},
        @{title='Anydesk';url='https://download.anydesk.com/AnyDesk.exe';Arguments=' /qn';Destination=$source},
        @{title='Foxit Reader';url='http://cdn01.foxitsoftware.com/pub/foxit/reader/desktop/win/9.x/9.7/en_us/FoxitReader97_Setup_Prom_IS.exe';Arguments=' /qn';Destination=$source}
        if ($User_Floor -eq 2) {
            @{title='WorkCenter 7225';url='http://download.support.xerox.com/pub/drivers/WC7220_WC7225/drivers/win10/ar/WC72XX_5.523.0.0_PrintSetup.exe';Arguments=' /qn';Destination=$source}
        }   
        elseif ($User_Floor -eq 1) {
            @{title='WorkCenter 7225';url='http://download.support.xerox.com/pub/drivers/WC7220_WC7225/drivers/win10/ar/WC72XX_5.523.0.0_PrintSetup.exe';Arguments=' /qn';Destination=$source}
        }
        elseif ($User_Floor -eq 0) {
            @{title='Versalink 7025';url='http://download.support.xerox.com/pub/drivers/6510/drivers/win10/ar/XeroxSmartStart_1.3.35.0.exe';Arguments=' /qn';Destination=$source}
        }
        else {
            break
        }
    ) 
   
    foreach ($package in $packages) { 
            $packageName = $package.title 
            $fileName = Split-Path $package.url -Leaf 
            $destinationPath = $package.Destination + "\" + $fileName 

        If (!(Test-Path -Path $destinationPath -PathType Leaf)) { 

            Write-Host "Downloading $packageName" 
            $webClient = New-Object System.Net.WebClient 
            $webClient.DownloadFile($package.url,$destinationPath) 
            } 
    }

    Rename-Item -Path $7ziprename -NewName "7zip.exe"

    #Once we've downloaded all our files lets install them. 
    foreach ($package in $packages) { 
        $packageName = $package.title 
        $fileName = Split-Path $package.url -Leaf 
        $destinationPath = $package.Destination + "\" + $fileName 
        $Arguments = $package.Arguments 
        Write-Output "Installing $packageName" 

        $jobinstall = Start-Job -ScriptBlock { Invoke-Expression -Command "$destinationPath $Arguments" }
        $jobinstall | Wait-Job
   }
}

CopyFilesfromSourcefolder
Install_Office
Download_and_Install_New_Softwares
