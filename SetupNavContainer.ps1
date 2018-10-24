try {
    if (!(Test-Path function:Log)) {
        function Log([string]$line, [string]$color = "Gray") {
            ("<font color=""$color"">" + [DateTime]::Now.ToString([System.Globalization.DateTimeFormatInfo]::CurrentInfo.ShortTimePattern.replace(":mm", ":mm:ss")) + " $line</font>") | Add-Content -Path "c:\demo\status.txt"
            Write-Host -ForegroundColor $color $line 
        }
    }

    Import-Module -name navcontainerhelper -DisableNameChecking

    . (Join-Path $PSScriptRoot "settings.ps1")

    $imageName = $navDockerImage.Split(',')[0]

    docker ps --filter name=$containerName -a -q | % {
        Log "Removing container $containerName"
        docker rm $_ -f | Out-Null
    }

    $BackupsUrl = "https://www.dropbox.com/s/5q8lrp3a3tqkcry/Demo%20Database%20NAV%20%2811-0%29%201CF.bak?dl=1"
    $BackupFolder = "C:\DOWNLOAD\Backups"
    $Filename = "$BackupFolder\Demo Database NAV (11-0) 1CF.bak"
    New-Item $BackupFolder -itemtype directory -ErrorAction ignore | Out-Null
    if (!(Test-Path $Filename)) {
        Download-File -SourceUrl $BackupsUrl  -destinationFile $Filename
    }
    $inspect = docker inspect $imageName | ConvertFrom-Json
    $country = $inspect.Config.Labels.country
    $navVersion = $inspect.Config.Labels.version
    $nav = $inspect.Config.Labels.nav
    $cu = $inspect.Config.Labels.cu
    $locale = Get-LocaleFromCountry $country

    #[Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.Filesystem") | Out-Null
    #[System.IO.Compression.ZipFile]::ExtractToDirectory($Filename,$BackupFolder )

    $ServersToCreate = Import-Csv "c:\demo\servers.csv" 
    $ServersToCreate |ForEach-Object {
        $containerName = $_.Server
        $bakupPath = "$BackupFolder\$($_.Backup)"
        $containerFolder = Join-Path "C:\ProgramData\NavContainerHelper\Extensions\" $containerName
        $dbBackupFileName = Split-Path $bakupPath -Leaf 
        $myFolder = Join-Path $containerFolder "my" 
    
        # CreateDevServerContainer -devContainerName $d -devImageName 'navdocker.azurecr.io/dynamics-nav:devpreview-september'
        # Copy-Item -Path "c:\myfolder\SetupNavUsers.ps1" -Destination "c:\DEMO\$d\my\SetupNavUsers.ps1"

        $securePassword = ConvertTo-SecureString -String $adminPassword -Key $passwordKey
        $credential = New-Object System.Management.Automation.PSCredential($navAdminUsername, $securePassword)
        <#
   $additionalParameters = @("--env bakfile=""C:\Run\my\${dbBackupFileName}""",
                             "--env RemovePasswordKeyFile=N"                             
                             )
    #>
        $additionalParameters = @("--env RemovePasswordKeyFile=N")
        $myScripts = @()
        Get-ChildItem -Path "c:\myfolder" | % { $myscripts += $_.FullName }
        $myScripts += $bakupPath;
        $myScripts += 'C:\DEMO\RestartNST.ps1';  
    
        Log "Running $imageName (this will take a few minutes)"
        New-NavContainer -accept_eula `
            -containerName $containerName `
            -auth Windows `
            -includeCSide `
            -doNotExportObjectsToText `
            -credential $credential `
            -additionalParameters $additionalParameters `
            -myScripts $myscripts `
            -licenseFile 'c:\demo\license.flf' `
            -imageName $imageName `
            -includeTestToolkit
                       
   

        $country = Get-NavContainerCountry -containerOrImageName $imageName
        $navVersion = Get-NavContainerNavVersion -containerOrImageName $imageName
        $locale = Get-LocaleFromCountry $country
    
        if (Test-Path "c:\demo\objects.fob" -PathType Leaf) {
            Log "Importing c:\demo\objects.fob to container"
            $sqlCredential = New-Object System.Management.Automation.PSCredential ( "sa", $credential.Password )
            Import-ObjectsToNavContainer -containerName $containerName -objectsFile "c:\demo\objects.fob" -sqlCredential $sqlCredential
        }

        # Copy .vsix and Certificate to container folder
        #$containerFolder = "C:\ProgramData\NavContainerHelper\Extensions\$containerName"
        $containerFolder = $myfolder
        Log "Copying .vsix and Certificate to $containerFolder"
        docker exec -it $containerName powershell "copy-item -Path 'C:\Run\*.vsix' -Destination '$containerFolder' -force
            copy-item -Path 'C:\Run\*.cer' -Destination '$containerFolder' -force
            copy-item -Path 'C:\Program Files\Microsoft Dynamics NAV\*\Service\CustomSettings.config' -Destination '$containerFolder' -force
            if (Test-Path 'c:\inetpub\wwwroot\http\NAV' -PathType Container) {
                [System.IO.File]::WriteAllText('$containerFolder\clickonce.txt','http://${publicDnsName}:8080/NAV')
            }"
        [System.IO.File]::WriteAllText("$containerFolder\Version.txt", $navVersion)
        [System.IO.File]::WriteAllText("$containerFolder\Cu.txt", $cu)
        [System.IO.File]::WriteAllText("$containerFolder\Country.txt", $country)
        [System.IO.File]::WriteAllText("$containerFolder\Title.txt", $title)

        Copy-Item -Path "$myFolder\*.vsix" -Destination "c:\DEMO\" -Recurse -Force -ErrorAction Ignore



        # Install Certificate on host
        $certFile = Get-Item "$containerFolder\*.cer"
        if ($certFile) {
            $certFileName = $certFile.FullName
            Log "Importing $certFileName to trusted root"
            $pfx = new-object System.Security.Cryptography.X509Certificates.X509Certificate2 
            $pfx.import($certFileName)
            $store = new-object System.Security.Cryptography.X509Certificates.X509Store([System.Security.Cryptography.X509Certificates.StoreName]::Root, "localmachine")
            $store.open("MaxAllowed") 
            $store.add($pfx) 
            $store.close()
        }

        Log -color Green "Container output"
        docker logs $containerName | % { log $_ }

        Log -color Green "Container setup complete!"

        Log "Using image $imageName"
        Log "Country $country"
        Log "Version $navVersion"
        Log "Locale $locale"

        # Copy .vsix and Certificate to container folder
        $demoFolder = "C:\Demo\"
        Log "Copying .vsix and Certificate to $demoFolder"
        docker exec -it $containerName powershell "copy-item -Path 'C:\Run\*.vsix' -Destination '$demoFolder' -force
            copy-item -Path 'C:\Run\*.cer' -Destination $demoFolder -force"
    }
    
    $img3 = 'microsoft/dynamics-nav:2018-cu6-nl'
    Log "Pulling image $img3"
    docker pull $img3

    $containerName = 'NAV2018CU6NL'
    $additionalParameters = @("--env bakfile=""C:\Run\my\Demo Database NAV (11-0) 1CF.bak""",
        "--env RemovePasswordKeyFile=N"                             
    )
    $myScripts = @()
    Get-ChildItem -Path "c:\myfolder" | % { $myscripts += $_.FullName }
    $myScripts += $bakupPath;
    $myScripts += 'C:\DEMO\RestartNST.ps1';  
    Log "Running $containerName (this will take a few minutes)"
    New-NavContainer -accept_eula `
        -containerName $containerName `
        -auth Windows `
        -includeCSide `
        -doNotExportObjectsToText `
        -credential $credential `
        -licenseFile 'c:\demo\license.flf' `
        -imageName $img3 `
        -includeTestToolkit
}
catch {
    Log -color Red -line ($Error[0].ToString() + " (" + ($Error[0].ScriptStackTrace -split '\r\n')[0] + ")")
}
