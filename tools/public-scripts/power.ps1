# Check and set power management setting for standby-timeout-ac
$currentTimeout = powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE | Select-String -Pattern "Power Setting Index: (.*)" | ForEach-Object { $_.Matches[0].Groups[1].Value.Trim() }

if ($currentTimeout -ne "0") {
    Write-Output "Current standby-timeout-ac is $currentTimeout. Changing to 0..."
    powercfg /CHANGE standby-timeout-ac 0
    Write-Output "standby-timeout-ac has been set to 0."
} else {
    Write-Output "standby-timeout-ac is already set to 0."
}