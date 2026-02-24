# Enable automatic time zone
reg add "HKLM\SYSTEM\CurrentControlSet\Services\tzautoupdate" /v Start /t REG_DWORD /d 3 /f

# Enable location service (if disabled)
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d Allow /f