# Remediation script for ConnectWise Control (ScreenConnect)

# This script is designed for use with Microsoft Intune remediation.  It
# silently downloads and installs the ConnectWise Control (ScreenConnect)
# agent if it is not present or if an older version is found.  It also
# removes any existing installation prior to reinstalling.  To use this
# script you must provide a valid MSI download URL from your ScreenConnect
# tenant.  Replace the placeholder in `$InstallerUrl` below with your
# organisation's download link.  The script writes detailed information to
# a log file for troubleshooting.

param()

$InstallerUrl = 'https://joshphillipssr.screenconnect.com/Bin/ScreenConnect.ClientSetup.msi?e=Access&y=Guest'

# Define the temporary path used for the downloaded MSI.  Using $env:TEMP
# ensures the folder exists and is writable for both standard users and
# system context (Intune runs scripts as the SYSTEM account).
$TempInstaller = Join-Path -Path $env:TEMP -ChildPath 'ScreenConnect.ClientSetup.msi'

# Define the log file path.  The C:\Windows\Temp directory is writable by
# the system account on most devices; adjust if necessary.
$LogPath = 'C:\Windows\Temp\ScreenConnect_Install_Log.txt'

# Service name patterns used to identify existing ScreenConnect/ConnectWise
# installations.  The wildcard allows matching names such as
# "ScreenConnect Client (abcd1234)" or "ConnectWise Control Client".
$ServicePatterns = @('ScreenConnect*', 'ConnectWise*')

function Write-Log {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "$timestamp - $Message"
    Write-Host $entry
    $entry | Out-File -FilePath $LogPath -Append -Encoding utf8
}

function Get-UninstallString {
    # Search both 64‑bit and 32‑bit uninstall registry hives for a product
    # whose DisplayName contains ScreenConnect or ConnectWise Control and
    # return its uninstall string.  Returns $null if not found.
    $candidates = @(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue) +
                  @(Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue)
    foreach ($item in $candidates) {
        if ($item.DisplayName -match 'ScreenConnect|ConnectWise Control') {
            return $item.UninstallString
        }
    }
    return $null
}

function Remove-ExistingInstallation {
    # Determine if any existing ScreenConnect/ConnectWise Control service is
    # present.  If present, attempt to uninstall using the uninstall string
    # from the registry.  Logs messages and aborts on failure.
    Write-Log 'Checking for existing installation...'
    $services = foreach ($pattern in $ServicePatterns) {
        Get-Service -Name $pattern -ErrorAction SilentlyContinue
    }
    if ($services) {
        Write-Log 'Existing service detected.  Beginning uninstallation.'
        $uninstallString = Get-UninstallString
        if ($uninstallString) {
            # The uninstall string typically follows the pattern "msiexec.exe /X{GUID}".
            if ($uninstallString -match 'msiexec\.exe\s*/X\s*(\{.*\})') {
                $productCode = $matches[1]
                Write-Log "Running msiexec to remove product code $productCode"
                try {
                    Start-Process 'msiexec.exe' -ArgumentList "/X $productCode /quiet /norestart" -Wait -NoNewWindow
                    Write-Log 'Uninstallation completed successfully.'
                } catch {
                    Write-Log "ERROR: Failed to uninstall existing installation.  Exception: $_"
                    exit 1
                }
            } else {
                Write-Log "WARNING: Uninstall string format not recognized: $uninstallString"
            }
        } else {
            Write-Log 'WARNING: Could not determine uninstall string; proceeding without removing existing installation.'
        }
    } else {
        Write-Log 'No existing installation detected.'
    }
}

function Download-Installer {
    param(
        [Parameter(Mandatory=$true)] [string] $Url,
        [Parameter(Mandatory=$true)] [string] $Destination
    )
    Write-Log "Downloading installer from $Url"
    try {
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
        Write-Log 'Download completed.'
    } catch {
        Write-Log "ERROR: Failed to download installer.  Exception: $_"
        exit 1
    }
}

function Install-Agent {
    param(
        [Parameter(Mandatory=$true)] [string] $InstallerPath
    )
    Write-Log 'Starting installation of ConnectWise Control / ScreenConnect agent.'
    try {
        Start-Process 'msiexec.exe' -ArgumentList "/i `"$InstallerPath`" /quiet /norestart" -Wait -NoNewWindow
        Write-Log 'Installation completed successfully.'
    } catch {
        Write-Log "ERROR: Installation failed.  Exception: $_"
        exit 1
    }
}

function Cleanup {
    param(
        [Parameter(Mandatory=$true)] [string] $FilePath
    )
    Write-Log "Cleaning up temporary file $FilePath"
    try {
        if (Test-Path $FilePath) {
            Remove-Item $FilePath -Force
            Write-Log 'Temporary file removed.'
        } else {
            Write-Log 'No temporary file found to remove.'
        }
    } catch {
        Write-Log "WARNING: Failed to delete temporary file.  Exception: $_"
    }
}

# -----------------------------------------------------------------------------
# Script execution
# -----------------------------------------------------------------------------

if ($InstallerUrl -eq '<REPLACE_WITH_YOUR_MSI_URL>' -or [string]::IsNullOrWhiteSpace($InstallerUrl)) {
    Write-Log 'ERROR: $InstallerUrl has not been configured.  Please edit the script and set a valid download URL before deploying via Intune.'
    exit 1
}

Remove-ExistingInstallation
Download-Installer -Url $InstallerUrl -Destination $TempInstaller
Install-Agent -InstallerPath $TempInstaller
Cleanup -FilePath $TempInstaller
Write-Log 'Remediation script completed.'
exit 0