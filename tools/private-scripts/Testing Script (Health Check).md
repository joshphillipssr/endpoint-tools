# Testing Script (Health Check)

## System Context
 -  Windows Services
   - SentinelHelperService
 - SentinelCtl.exe
 - Agent Version
 - MSI Registration
 - Upgrade Code Linkage
 - API Status
 - Reboot status (API)
 - Reboot status (system)
 


  - Execute SentinelOneInstaller.exe -o.
  - Check the Exit Code. If non-zero, the agent is unhealthy.
  - If the exit code is 0, parse the resulting .csv log file.
    - Primary Health Validation:
      - Confirm the presence of InstalledAgentVersionFoundFromExeFile.
      - Confirm the presence of FoundAgentUid and FoundSiteToken.
      - Parse the BuildBasicTelemetryMetadata event and specifically check that rebootWasRequired is 0.
- If all these checks pass, we can consider the agent "Compliant / Healthy" as per our flowchart. If any check fails, we proceed to the "Uninstallation Script (Tiered Remediation)".