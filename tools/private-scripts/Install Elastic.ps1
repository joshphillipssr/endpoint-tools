param(
    [Parameter(Mandatory = $true)]
    [string]$EnrollmentToken,

    [Parameter(Mandatory = $true)]
    [string]$FleetUrl,

    [string]$AgentVersion = '8.2.3',

    [switch]$ForceReinstall
)

$ErrorActionPreference = 'Stop'

$agentUrl = "https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-$AgentVersion-windows-x86_64.zip"
$service = Get-Service -Name 'Elastic Agent' -ErrorAction SilentlyContinue

if ($service -and $service.Status -eq 'Running' -and -not $ForceReinstall) {
    Write-Host 'Elastic Agent is already running. Use -ForceReinstall to reinstall.'
    exit 0
}

Write-Host "Installing Elastic Agent version $AgentVersion"

$tempDir = Join-Path -Path $env:TEMP -ChildPath ([guid]::NewGuid().ToString('N'))
$zipFile = Join-Path -Path $tempDir -ChildPath 'elastic-agent.zip'

New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
Start-BitsTransfer -Source $agentUrl -Destination $zipFile
Expand-Archive -LiteralPath $zipFile -DestinationPath $tempDir -Force

$agentRoot = Join-Path -Path $tempDir -ChildPath "elastic-agent-$AgentVersion-windows-x86_64"
$exeFile = Join-Path -Path $agentRoot -ChildPath 'elastic-agent.exe'

if (-not (Test-Path -LiteralPath $exeFile)) {
    throw "Elastic Agent executable not found at $exeFile"
}

$process = Start-Process -FilePath $exeFile -ArgumentList @(
    'install',
    '-f',
    "--url=$FleetUrl",
    "--enrollment-token=$EnrollmentToken"
) -PassThru -Wait -NoNewWindow

if ($process.ExitCode -ne 0) {
    throw "Elastic Agent installation failed with exit code $($process.ExitCode)"
}

Write-Host 'Elastic Agent installation completed successfully.'
