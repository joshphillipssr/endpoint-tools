function Test-PendingReboot {
    [CmdletBinding()]
    param ()

    $PendingReboot = $false
    $Reasons = @()

    # Check CBS
    if (Test-Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
        $Reasons += "Component Based Servicing"
        $PendingReboot = $true
    }

    # Check Windows Update
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
        $Reasons += "Windows Update"
        $PendingReboot = $true
    }

    # Check PendingFileRenameOperations
    $PendingFileRenameOps = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue
    if ($PendingFileRenameOps) {
        $Reasons += "Pending File Rename Operations"
        $PendingReboot = $true
    }

    # Check SCCM
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\CCM\PendingReboot") {
        $Reasons += "SCCM Client"
        $PendingReboot = $true
    }

    # Output
    [PSCustomObject]@{
        PendingReboot = $PendingReboot
        Reasons       = if ($PendingReboot) { $Reasons } else { "None" }
    }
}