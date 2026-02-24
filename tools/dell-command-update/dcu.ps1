function Log {
    param (
        [string]$Text
    )
    $timestamp = "{0:yyyy-MM-dd HH:mm:ss}" -f [DateTime]::Now
    Write-Output "$timestamp - $Text"
}

$ScriptVersion = '24.10.3.7'
Write-Output "Dell Command Update Functions Loaded - Version $ScriptVersion"

function Get-DellSupportedModels {
    [CmdletBinding()]
    
    $CabPathIndex = "$env:ProgramData\CMSL\DellCabDownloads\CatalogIndexPC.cab"
    $DellCabExtractPath = "$env:ProgramData\CMSL\DellCabDownloads\DellCabExtract"
    
    # Pull down Dell XML CAB used in Dell Command Update ,extract and Load
    if (!(Test-Path $DellCabExtractPath)){$null = New-Item -Path $DellCabExtractPath -ItemType Directory -Force}
    Write-Verbose "Downloading Dell Cab"
    Invoke-WebRequest -Uri "https://downloads.dell.com/catalog/CatalogIndexPC.cab" -OutFile $CabPathIndex -UseBasicParsing
    If(Test-Path "$DellCabExtractPath\DellSDPCatalogPC.xml"){Remove-Item -Path "$DellCabExtractPath\DellSDPCatalogPC.xml" -Force}
    Start-Sleep -Seconds 1
    if (Test-Path $DellCabExtractPath){Remove-Item -Path $DellCabExtractPath -Force -Recurse}
    $null = New-Item -Path $DellCabExtractPath -ItemType Directory
    Write-Verbose "Expanding the Cab File..." 
    $null = expand $CabPathIndex $DellCabExtractPath\CatalogIndexPC.xml
    
    Write-Verbose "Loading Dell Catalog XML.... can take awhile"
    [xml]$XMLIndex = Get-Content "$DellCabExtractPath\CatalogIndexPC.xml"
    
    $SupportedModels = $XMLIndex.ManifestIndex.GroupManifest
    $SupportedModelsObject = @()
    foreach ($SupportedModel in $SupportedModels){
        $SPInventory = New-Object -TypeName PSObject
        $SPInventory | Add-Member -MemberType NoteProperty -Name "SystemID" -Value "$($SupportedModel.SupportedSystems.Brand.Model.systemID)" -Force
        $SPInventory | Add-Member -MemberType NoteProperty -Name "Model" -Value "$($SupportedModel.SupportedSystems.Brand.Model.Display.'#cdata-section')"  -Force
        $SPInventory | Add-Member -MemberType NoteProperty -Name "URL" -Value "$($SupportedModel.ManifestInformation.path)" -Force
        $SPInventory | Add-Member -MemberType NoteProperty -Name "Date" -Value "$($SupportedModel.ManifestInformation.version)" -Force		
        $SupportedModelsObject += $SPInventory 
    }
    return $SupportedModelsObject
}

Function Get-DCUVersion {
    $DCU=(Get-ItemProperty "HKLM:\SOFTWARE\Dell\UpdateService\Clients\CommandUpdate\Preferences\Settings" -ErrorVariable err -ErrorAction SilentlyContinue)
    if ($err.Count -eq 0) {
        $DCU = $DCU.ProductVersion
    }else{
        $DCU = $false
    }
    return $DCU
}

Function Get-DCUAppCode {
    try {
        $AppCode = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\DELL\UpdateService\Clients\CommandUpdate\Preferences\Settings" -Name "AppCode" -ErrorAction Stop
        return $AppCode
    }
    catch {
        return $null
    }
}

Function Uninstall-DCU {
    [CmdletBinding()]
    param()
    
    # Attempt to uninstall Dell Command Update if the Universal version is detected
    $DCUApp = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "Dell Command*Update*" }
    if ($DCUApp) {
        Write-Verbose "Uninstalling Dell Command | Update Universal version..."
        $DCUApp.Uninstall() | Out-Null
        Start-Sleep -Seconds 10  # Wait for a few seconds to ensure the uninstallation completes
    }
    else {
        Write-Verbose "No Dell Command | Update Universal version found to uninstall."
    }
}

Function Install-DCU {
    [CmdletBinding()]
    param()
    $temproot = "$env:windir\temp"
    
    $Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
    $CabPathIndexModel = "$temproot\DellCabDownloads\CatalogIndexModel.cab"
    $DellCabExtractPath = "$temproot\DellCabDownloads\DellCabExtract"
    if (!(Test-Path $DellCabExtractPath)){$null = New-Item -Path $DellCabExtractPath -ItemType Directory -Force}
    $DCUVersionInstalled = Get-DCUVersion
    
    if ($Manufacturer -notmatch "Dell"){return "This Function is only for Dell Systems"}

    # Check for Universal version
    $AppCode = Get-DCUAppCode
    if ($AppCode -eq "Universal") {
        Write-Verbose "The Universal version of Dell Command Update is installed. Uninstalling it before proceeding with Generic version installation."
        Uninstall-DCU
    }

    #Create Folders
    Write-Verbose "Creating Folders"
    if (!(Test-Path -Path $DellCabExtractPath)){New-Item -Path $DellCabExtractPath -ItemType Directory -Force | Out-Null}  
    
    $SystemSKUNumber = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber
    Write-Verbose "Using Dell Catalog to get Latest DCU Version - $SystemSKUNumber"
    $DellSKU = Get-DellSupportedModels | Where-Object {$_.systemID -match $SystemSKUNumber} | Select-Object -First 1
    Write-Verbose "Using Catalog from $($DellSKU.Model)"
    if (Test-Path $CabPathIndexModel){Remove-Item -Path $CabPathIndexModel -Force}
    Invoke-WebRequest -Uri "http://downloads.dell.com/$($DellSKU.URL)" -OutFile $CabPathIndexModel -UseBasicParsing

    # Retry extraction process if the XML file is not found
    $maxRetries = 3
    $retryCount = 0
    $extractedSuccessfully = $false

    while (-not $extractedSuccessfully -and $retryCount -lt $maxRetries) {
        Write-Verbose "Attempting to extract Dell Catalog (Attempt $($retryCount + 1) of $maxRetries)..."
        $null = expand $CabPathIndexModel "$DellCabExtractPath\CatalogIndexPCModel.xml"

        if (Test-Path "$DellCabExtractPath\CatalogIndexPCModel.xml") {
            Write-Verbose "Dell Catalog XML successfully extracted."
            $extractedSuccessfully = $true
        } else {
            Write-Verbose "Error: The Catalog XML could not be found after extraction. Retrying..."
            Start-Sleep -Seconds 5  # Wait before retrying
            $retryCount++
        }
    }

    if (-not $extractedSuccessfully) {
        Write-Verbose "Error: The Catalog XML could not be extracted after $maxRetries attempts. Exiting function."
        return
    }

    [xml]$XMLIndexCAB = Get-Content "$DellCabExtractPath\CatalogIndexPCModel.xml" -ErrorAction Stop
    if ($null -eq $XMLIndexCAB.Manifest.SoftwareComponent) {
        Write-Verbose "Error: Unable to find 'SoftwareComponent' in the extracted XML catalog."
        return
    }

    $DCUAppsAvailable = $XMLIndexCAB.Manifest.SoftwareComponent | Where-Object { $_.ComponentType -and $_.ComponentType.value -eq "APAC" }

    # Debugging each component to understand the structure
    Write-Verbose "Extracting Available Updates from Catalog XML..."
    foreach ($component in $DCUAppsAvailable) {
        Write-Verbose "Component Name: $($component.Name.Display.'#cdata-section')"
        Write-Verbose "Component Version: $($component.vendorVersion)"
        Write-Verbose "Component Type: $($component.ComponentType.Display.'#cdata-section')"
    }
    
    #Using Generic Version:
    $AppDCUVersion = ([Version[]]($DCUAppsAvailable | Where-Object {$_.path -match 'command-update' -and $_.SupportedOperatingSystems.OperatingSystem.osArch -match "x64"}).vendorVersion) | Sort-Object | Select-Object -Last 1
    $AppDCU = $DCUAppsAvailable | Where-Object {$_.path -match 'command-update' -and $_.SupportedOperatingSystems.OperatingSystem.osArch -match "x64" -and $_.vendorVersion -eq $AppDCUVersion}
    if ($AppDCU.Count -gt 1){
        $AppDCU = $AppDCU | Select-Object -First 1
    }
    if ($AppDCU){
        Write-Verbose $AppDCU
        $DellItem = $AppDCU
        If ($DCUVersionInstalled -ne $false){
            [Version]$CurrentVersion = [Version]$DCUVersionInstalled
        }
        Else {
            [Version]$CurrentVersion = [Version]"0.0.0.0"
        }
        [Version]$DCUVersion = [Version]$DellItem.vendorVersion
        
        $DCUReleaseDate = $($DellItem.releaseDate)              
        $TargetLink = "http://downloads.dell.com/$($DellItem.path)"
        Write-Verbose "Generated Download URL: $TargetLink"
        $TargetFileName = ($DellItem.path).Split("/") | Select-Object -Last 1
        
        if ($DCUVersion -gt $CurrentVersion){
            if ($CurrentVersion -eq [Version]"0.0.0.0"){[String]$CurrentVersion = "Not Installed"}
            Write-Output "New Update available: Installed = $CurrentVersion DCU = $DCUVersion"
            Write-Output "Title: $($DellItem.Name.Display.'#cdata-section')"
            Write-Output "----------------------------"
            Write-Output "Severity: $($DellItem.Criticality.Display.'#cdata-section')"
            Write-Output "FileName: $TargetFileName"
            Write-Output "Release Date: $DCUReleaseDate"
            Write-Output "KB: $($DellItem.releaseID)"
            Write-Output "Link: $TargetLink"
            Write-Output "Info: $($DellItem.ImportantInfo.URL)"
            Write-Output "Version: $DCUVersion "
            
            #Build Required Info to Download and Update CM Package
            $TargetFilePathName = "$DellCabExtractPath\$TargetFileName"
            Start-BitsTransfer -Source $TargetLink -Destination $TargetFilePathName -DisplayName $TargetFileName -Description "Downloading Dell Command Update" -Priority Low -ErrorVariable err -ErrorAction SilentlyContinue
            if (!(Test-Path $TargetFilePathName)){
                Invoke-WebRequest -Uri $TargetLink -OutFile $TargetFilePathName -UseBasicParsing -Verbose
            }

            #Confirm Download
            if (Test-Path $TargetFilePathName){
                $LogFileName = $TargetFilePathName.replace(".exe",".log")
                $Arguments = "/s /l=$LogFileName"
                Write-Output "Starting Update"
                write-output "Log file = $LogFileName"
                $Process = Start-Process "$TargetFilePathName" $Arguments -Wait -PassThru
                write-output "Update Complete with Exitcode: $($Process.ExitCode)"
                If($null -ne $Process -and $Process.ExitCode -eq '2'){
                    Write-Verbose "Reboot Required"
                }
            }
        }
        else {
            Write-Verbose "The installed version ($CurrentVersion) is up to date. No update required."
        }
    }
    else {
        Write-Verbose "No DCU Update Available"
    }
}

#Execute
Install-DCU
