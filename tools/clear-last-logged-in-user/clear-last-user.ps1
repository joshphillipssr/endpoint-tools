param (
    [string]$TargetComputer,
    [string]$UserName
)

function Log {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$timestamp - $Message"
}

Log "Starting removal of user $UserName from recently logged-in users on $TargetComputer."

# Connect to the remote machine
Log "Connecting to remote computer $TargetComputer..."
$session = New-PSSession -ComputerName $TargetComputer -ErrorAction Stop

Invoke-Command -Session $session -ScriptBlock {
    param($UserName)

    # Remove cached last logged-in user from LogonUI registry key
    Log "Removing last logged-in user from registry..."
    Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI' -Name 'LastLoggedOnUser' -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI' -Name 'LastLoggedOnUserSID' -ErrorAction SilentlyContinue

    # Find and delete user profile
    Log "Checking for user profile..."
    $profile = Get-WmiObject Win32_UserProfile | Where-Object { $_.LocalPath -like "*$UserName*" }
    if ($profile) {
        Log "Found profile: $($profile.LocalPath). Deleting..."
        $profile.Delete()
    } else {
        Log "No profile found for user $UserName."
    }

    # Clear cached credentials (if applicable)
    Log "Clearing credential cache..."
    cmdkey /delete:$UserName 2>&1 | Out-Null

    # Optional: Clear relevant security event logs (requires elevated permissions)
    Log "Clearing security logs..."
    wevtutil cl Security

    Log "Operation completed."
} -ArgumentList $UserName

# Close the remote session
Remove-PSSession -Session $session

Log "Disconnected from $TargetComputer."
Log "Script execution completed."
