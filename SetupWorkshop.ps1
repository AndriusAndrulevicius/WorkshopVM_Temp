try {
    $Folder = "C:\DOWNLOAD\AdobeReader"
    $Filename = "$Folder\AdbeRdr11010_en_US.exe"
    New-Item $Folder -itemtype directory -ErrorAction ignore | Out-Null
    
    #if (!(Test-Path $Filename)) {
    #    Log "Downloading Adobe Reader"
    #    $WebClient = New-Object System.Net.WebClient
    #    $WebClient.DownloadFile("http://ardownload.adobe.com/pub/adobe/reader/win/11.x/11.0.10/en_US/AdbeRdr11010_en_US.exe", $Filename)
    #}
    
    #Log "Installing Adobe Reader (this should only take a few minutes)"
    #Start-Process $Filename -ArgumentList "/msi /qn" -Wait -Passthru | Out-Null
    #Start-Sleep -Seconds 10

    #1CF Setup report builder
    Log "Installing .NET"
    Install-WindowsFeature Net-Framework-Core 

    Log "Installing SQL Report Builder"
    #SQL 2014 
    #$sqlrepbuilderURL= "https://download.microsoft.com/download/2/E/1/2E1C4993-7B72-46A4-93FF-3C3DFBB2CEE0/ENU/x86/ReportBuilder3.msi"
    #SQL 2016
    $sqlrepbuilderURL= "https://www.dropbox.com/s/qfjdpe9nb2xsnd5/ReportBuilder3.msi?dl=1"
    
    $sqlrepbuilderPath = "c:\download\ReportBuilder3.msi"

    Download-File -sourceUrl $sqlrepbuilderURL -destinationFile  $sqlrepbuilderPath
    Start-Process "C:\Windows\System32\msiexec.exe" -argumentList "/i $sqlrepbuilderPath /quiet" -wait

    Log "Installing O365"
    $OfficeInstallURL = "https://www.dropbox.com/s/zuml2cyeqjnhvm5/Setup.X64.en-us_O365ProPlusRetail_08238891-9e8e-4522-95f3-0763ab460a7c_TX_DB_b_48_.exe?dl=1"
    $OfficeInstall = "c:\download\O365.exe"
    Invoke-WebRequest -Uri $OfficeInstallURL -OutFile $OfficeInstall
    Start-Process $OfficeInstall -Wait
} catch {
    Log -color Red -line ($Error[0].ToString() + " (" + ($Error[0].ScriptStackTrace -split '\r\n')[0] + ")")
}
