# Stop Windows Update services
Write-Output "Stopping Windows Update services..."
Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
Stop-Service -Name bits -Force -ErrorAction SilentlyContinue
Stop-Service -Name cryptsvc -Force -ErrorAction SilentlyContinue

# Rename or delete the SoftwareDistribution and Catroot2 folders
Write-Output "Renaming SoftwareDistribution and Catroot2 folders..."
Rename-Item -Path "C:\Windows\SoftwareDistribution" -NewName "SoftwareDistribution.old" -ErrorAction SilentlyContinue
Rename-Item -Path "C:\Windows\System32\catroot2" -NewName "catroot2.old" -ErrorAction SilentlyContinue

# If rename fails, delete the folders instead
if (-Not (Test-Path "C:\Windows\SoftwareDistribution.old")) {
    Remove-Item -Path "C:\Windows\SoftwareDistribution" -Recurse -Force -ErrorAction SilentlyContinue
}
if (-Not (Test-Path "C:\Windows\System32\catroot2.old")) {
    Remove-Item -Path "C:\Windows\System32\catroot2" -Recurse -Force -ErrorAction SilentlyContinue
}

# Start Windows Update services again
Write-Output "Starting Windows Update services..."
Start-Service -Name wuauserv -ErrorAction SilentlyContinue
Start-Service -Name bits -ErrorAction SilentlyContinue
Start-Service -Name cryptsvc -ErrorAction SilentlyContinue

Write-Output "Windows Update has been reset successfully."
