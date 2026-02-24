# Detection script for ConnectWise Control (ScreenConnect)

# This detection script is intended for use with Microsoft Intune remediation
# policies.  It returns exit code 0 when the ConnectWise Control (formerly
# ScreenConnect) agent is installed on the endpoint and exit code 1 when it
# is not installed.  The script checks both 64‑bit and 32‑bit uninstall
# registry hives as well as running services to account for different
# installation scenarios and naming conventions.

try {
    # Look in the 64‑bit uninstall registry for DisplayName entries that
    # mention either ScreenConnect or ConnectWise Control.  If a matching
    # entry is found we treat the agent as installed.
    $reg64 = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -match 'ScreenConnect|ConnectWise Control' }

    # Look in the 32‑bit uninstall registry for the same pattern.  This is
    # necessary on 64‑bit Windows where 32‑bit applications write to the
    # WOW6432Node hive.
    $reg32 = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -match 'ScreenConnect|ConnectWise Control' }

    # In addition to registry entries, check for running services that start
    # with the expected name patterns.  Some deployments name the service
    # differently (for example, ConnectWise Control Client) so we broaden
    # the search to include any service beginning with ScreenConnect or
    # ConnectWise.
    $services = @( Get-Service -Name 'ScreenConnect*' -ErrorAction SilentlyContinue ) +
                @( Get-Service -Name 'ConnectWise*' -ErrorAction SilentlyContinue )

    if ($reg64 -or $reg32 -or $services.Count -gt 0) {
        Write-Output 'ConnectWise Control / ScreenConnect agent is installed.'
        exit 0  # compliant
    } else {
        Write-Output 'ConnectWise Control / ScreenConnect agent is NOT installed.'
        exit 1  # non‑compliant
    }
} catch {
    # If any unexpected error occurs during detection, log it and return
    # non‑compliant so that remediation can be triggered.  Intune will
    # surface the error output in the script logs for troubleshooting.
    Write-Output "ERROR: An exception occurred in the detection script - $_"
    exit 1
}