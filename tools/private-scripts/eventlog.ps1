param(
    [int[]]$EventIds = @(1097, 1098),
    [string]$LogName = 'Microsoft-Windows-AAD/Operational',
    [string]$OutputPath = "$env:TEMP\\AAD_Events_1097_1098.json",
    [int]$MaxEvents = 1000
)

$ErrorActionPreference = 'Stop'

$events = Get-WinEvent -FilterHashtable @{
    LogName = $LogName
    Id = $EventIds
} | Select-Object -First $MaxEvents | ForEach-Object {
    [pscustomobject]@{
        Id = $_.Id
        TimeCreated = $_.TimeCreated
        ProviderName = $_.ProviderName
        LevelDisplayName = $_.LevelDisplayName
        Message = $_.Message
        RecordId = $_.RecordId
        Properties = $_.Properties | ForEach-Object { $_.Value }
    }
}

$events | ConvertTo-Json -Depth 5 | Out-File -FilePath $OutputPath -Encoding UTF8
Write-Host "Exported event data to $OutputPath"
