# To execute from backstage and then close session so uninstall will succeed
# Start-Sleep -Seconds 10

# Variables
$installerUrl = "https://joshphillipssr.screenconnect.com/Bin/JPsupport.ClientSetup.msi?e=Access&y=Guest"
$tempPath = "$env:TEMP\ScreenConnect.ClientSetup.msi"
$logPath = "C:\Windows\Temp\ScreenConnect_Install_Log.txt"
$serviceName = "ScreenConnect Client*"

# Logging Function
function Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $Message"
    Write-Host $logMessage
    $logMessage | Out-File -Append -FilePath $logPath
}

# Function to find the uninstall string for ScreenConnect
function Get-ScreenConnectUninstallString {
    # Check 64-bit registry
    $uninstallString = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*ScreenConnect*" } |
        Select-Object -ExpandProperty UninstallString -First 1

    # Check 32-bit registry if not found in 64-bit
    if (-not $uninstallString) {
        $uninstallString = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "*ScreenConnect*" } |
            Select-Object -ExpandProperty UninstallString -First 1
    }

    return $uninstallString
}

# Check if ScreenConnect is already installed
Log "Checking if ScreenConnect is already installed..."
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if ($service) {
    Log "ScreenConnect service found. Attempting to uninstall..."
    # Get the uninstall string
    $uninstallString = Get-ScreenConnectUninstallString

    if ($uninstallString) {
        # Extract the GUID from the uninstall string
        if ($uninstallString -match "msiexec\.exe /X(\{.*\})") {
            $productCode = $matches[1]
            Log "Found product code: $productCode. Running uninstaller..."
            try {
                # Run the uninstaller silently with the extracted GUID
                Start-Process msiexec.exe -ArgumentList "/X $productCode /quiet /norestart" -Wait -NoNewWindow
                Log "ScreenConnect uninstalled successfully."
            } catch {
                Log "ERROR: Failed to uninstall ScreenConnect. Exception: $_"
                exit 1
            }
        } else {
            Log "ERROR: Uninstall string format is not recognized: $uninstallString"
        }
    } else {
        Log "ERROR: Could not find the uninstaller in the registry."
    }
} else {
    Log "ScreenConnect is not installed. Proceeding with installation..."
}

# Download the installer
Log "Downloading ScreenConnect installer from $installerUrl..."
try {
    Invoke-WebRequest -Uri $installerUrl -OutFile $tempPath -UseBasicParsing
    Log "Download completed successfully."
} catch {
    Log "ERROR: Failed to download the installer. Exception: $_"
    exit 1
}

# Install the ScreenConnect agent
Log "Starting ScreenConnect agent installation..."
try {
    Start-Process msiexec.exe -ArgumentList "/i `"$tempPath`" /quiet /norestart" -Wait -NoNewWindow
    Log "ScreenConnect agent installed successfully."
} catch {
    Log "ERROR: Failed to install the agent. Exception: $_"
    exit 1
}

# Clean up
Log "Cleaning up temporary files..."
try {
    Remove-Item $tempPath -Force
    Log "Temporary files removed."
} catch {
    Log "ERROR: Failed to remove temporary files. Exception: $_"
}

Log "Script execution completed."