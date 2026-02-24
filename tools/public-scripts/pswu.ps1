# Check if NuGet package provider is installed
if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Write-Output "NuGet package provider not found. Installing..."
    Install-PackageProvider -Name NuGet -Force
} else {
    Write-Output "NuGet package provider is already installed."
}

# Check if PSWindowsUpdate module is installed
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Output "PSWindowsUpdate module not found. Installing..."
    Install-Module -Name PSWindowsUpdate -Force -AllowClobber | Out-Default
} else {
    Write-Output "PSWindowsUpdate module is already installed."
}