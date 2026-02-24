# SentinelOne Dynamic Version Script - EXE Preferred (Immy Compatibility Fix)
# PURPOSE: Fetches available agent packages from the S1 API and prioritizes .exe installers
# over .msi installers, as per S1 recommendations and internal troubleshooting findings.

Import-Module SentinelOne
$AuthHeader = Connect-S1API -S1Uri $SentinelOneUri -S1ApiToken $ApiKey  
$AuthHeader | Out-String | Write-Verbose

$SystemInfo = Invoke-S1RestMethod -Endpoint 'system/info'
$QueryParameters = @{
    limit          = 50
    status         = 'ga'
    sortBy         = 'version'
    sortOrder      = 'desc'
    osTypes        = 'windows'
    fileExtensions = '.exe,.msi' 
    osArches       = '64 bit,32 bit,ARM64'
}
try
{
    Write-Output "Fetching all available Download Links (.exe and .msi)..."
    $DownloadLinks = Invoke-S1RestMethod -Endpoint "update/agent/packages" -QueryParameters $QueryParameters
    Write-Verbose "Retrieved $($DownloadLinks.Count) package links. Now grouping and prioritizing..."
    $DownloadLinks | Format-List * | Out-String | Write-Verbose

    # Using an ordered dictionary is still the correct approach for predictable output.
    $GroupedVersions = [ordered]@{}

    # === PASS 1: GATHER AND GROUP ===
    foreach ($link in $DownloadLinks) {
        if ($link.fileName -like "storage-agent-installer*") { continue }
        
        $Version = [Version]$link.Version
        
        $FileArchitecture = switch ($link.OsArch) {
            '64 bit' { "X64" }
            '32 bit' { "X86" }
            'ARM64'  { 'ARM64' }
            default  { continue }
        }

        $GroupKey = "$Version-$FileArchitecture"

        # FIX: Use a more compatible check for the key's existence that works in older PowerShell versions.
        # The .ContainsKey() method does not exist on the [ordered] dictionary type in this environment.
        if (-not $GroupedVersions[$GroupKey]) {
            $GroupedVersions[$GroupKey] = @{
                Version      = $Version
                Architecture = $FileArchitecture
                EXE          = $null
                MSI          = $null
            }
        }

        if ($link.fileExtension -eq '.exe') {
            $GroupedVersions[$GroupKey].EXE = $link
        }
        elseif ($link.fileExtension -eq '.msi') {
            $GroupedVersions[$GroupKey].MSI = $link
        }
    }

    # === PASS 2: PRIORITIZE AND CREATE DYNAMIC VERSIONS ===
    $Versions = foreach ($group in $GroupedVersions.GetEnumerator()) {
        $versionData = $group.Value

        # Prioritize EXE over MSI
        if ($versionData.EXE) {
            Write-Verbose "Version $($versionData.Version) ($($versionData.Architecture)): Found EXE installer (Preferred). Creating dynamic version."
            New-DynamicVersion -Url $versionData.EXE.link -Version $versionData.Version -FileName $versionData.EXE.fileName -Architecture $versionData.Architecture -PackageType Executable
        }
        elseif ($versionData.MSI) {
            Write-Verbose "Version $($versionData.Version) ($($versionData.Architecture)): EXE not found. Falling back to MSI installer."
            New-DynamicVersion -Url $versionData.MSI.link -Version $versionData.Version -FileName $versionData.MSI.fileName -Architecture $versionData.Architecture -PackageType MSI
        }
        else {
             Write-Warning "Version $($versionData.Version) ($($versionData.Architecture)): No valid EXE or MSI installer found. Skipping."
        }
    }

    $Response = @{
        Versions = @($Versions)
    }
    Write-Output $Response
} 
catch 
{
    if($_.ErrorDetails.Message) {
        $e = $_.ErrorDetails.Message | ConvertFrom-Json | Select-Object errors
        throw "Error connecting to SentinelOne API: $($e.errors.title)"
    } else {
        throw "Error connecting to SentinelOne API: $_"
    }    
}