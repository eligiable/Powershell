#Create Folder to Store Software
New-Item -ItemType directory -Path C:\Downloads

#Run the Command to Download Sofware
Get-Content 'Installers.txt' | % { Invoke-WebRequest $_ -OutFile ($_ -replace '^.*?([^/]+$)', '$1') }

#Check if .NET Framwork 3.5 is installed or not
#Get-WindowsOptionalFeature -Online | Where-Object -FilterScript {$_.featurename -Like "*netfx3*"}

#Install .NET Framework 3.5
Enable-WindowsOptionalFeature -Online -FeatureName "NetFx3" -All

#Install the Downloaded Software
$SoftwaretoInstall = @("C:\Downloads\7z1900-x64.exe","C:\Downloads\ccsetup576.exe","C:\Downloads\ChromeSetup.exe","C:\Downloads\Firefox%20Installer.exe","C:\Downloads\FoxitReader1011_Setup_Prom_IS.exe","C:\Downloads\GoogleDriveFSSetup.exe","C:\Downloads\TeamViewer_Setup.exe","C:\Downloads\vlc-3.0.12-win64.exe","C:\Downloads\Webex.msi","C:\Downloads\WPSOffice_11.2.0.9984.exe","C:\Downloads\ZoomInstaller.exe","RingCentral.exe","XeroxSmartStart_1.5.49.0.exe")
foreach($Software in $SoftwaretoInstall) {
    Start-Process -FilePath $Software -ArgumentList "/qn" -Wait
}

#Create Local User
$UserName = Read-Host -Prompt "Please Enter a Username"
New-LocalUser -Name $UserName -NoPassword