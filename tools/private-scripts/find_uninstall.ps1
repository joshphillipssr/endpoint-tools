param(
    [string]$SearchString
)

if ([string]::IsNullOrWhiteSpace($SearchString)) {
    $SearchString = Read-Host -Prompt "Enter the search string for the program to find (for example Screenconnect*)"
}

$uninstallEntries64 = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like "*$SearchString*" } |
    Select-Object DisplayName, UninstallString

$uninstallEntries32 = Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like "*$SearchString*" } |
    Select-Object DisplayName, UninstallString

$results = @($uninstallEntries64) + @($uninstallEntries32)
if ($results.Count -gt 0) {
    Write-Host "Found the following uninstall entries:"
    $results | ForEach-Object {
        Write-Host "Display Name: $($_.DisplayName)"
        Write-Host "Uninstall String: $($_.UninstallString)"
        Write-Host '---------------------------'
    }
} else {
    Write-Host "No uninstall entries found for the search string '$SearchString'."
}
