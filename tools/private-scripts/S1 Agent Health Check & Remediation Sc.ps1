# S1 Agent Health Check & Remediation Script (Immy Maintenance Task Version - Final Merged Logic)
#
# WORKFLOW:
# This script is designed to be run from a custom ImmyBot Maintenance Task.
# It assumes that the ImmyBot environment is providing the following variables:
# - $SentinelOneUri, $ApiKey, $Passphrase

$ProgressPreference = 'SilentlyContinue'
$VerbosePreference = 'Continue'

try {
    Write-Verbose "--- S1 Health Check & In-Place Remediation started in METASCRIPT context ---"

    # --- Pre-flight Check: Validate Environment Variables ---
    if ([string]::IsNullOrWhiteSpace($Passphrase)) {
        throw "Passphrase variable was not provided by the ImmyBot environment. Please ensure the custom Maintenance Task is configured correctly with a 'Passphrase' parameter."
    }
    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        throw "ApiKey variable was not provided by the ImmyBot environment. Please ensure the SentinelOne Integration is configured correctly."
    }
    Write-Verbose "All required credentials (ApiKey, Passphrase) have been provided by the environment."

    Write-Verbose "Importing SentinelOne module and connecting to API..."
    Import-Module SentinelOne -ErrorAction Stop
    Connect-S1API -S1Uri $SentinelOneUri -S1ApiToken $ApiKey | Out-Null
    Write-Verbose "SentinelOne context loaded successfully."

    # === PHASE 1: UNIFIED CHECK & REMEDIATION ===
    Write-Verbose "[Phase 1] Performing unified agent check and in-place remediation..."
    $finalResultObject = Invoke-ImmyCommand {
        
        # --- Helper Function ---
        function Get-SentinelCtlPath {
            try {
                $helper = New-Object -ComObject "SentinelHelper.1"
                $agentStatus = $helper.GetAgentStatusJSON() | ConvertFrom-Json
                $agentVersion = $agentStatus[0].'agent-version'
                $ctlPath = "C:\Program Files\SentinelOne\Sentinel Agent $agentVersion\SentinelCtl.exe"
                if (Test-Path -LiteralPath $ctlPath) { return $ctlPath }
            }
            catch {
                Write-Warning "COM object method failed. Falling back to wildcard search..."
            }
            $ctlPath = Get-ChildItem -Path 'C:\Program Files\SentinelOne\Sentinel Agent*\SentinelCtl.exe' -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
            if ($ctlPath -and (Test-Path -LiteralPath $ctlPath)) { return $ctlPath }
            throw "Could not locate SentinelCtl.exe after trying both COM and file system search methods."
        }

        # --- Main Logic within the single script block ---
        try {
            # 1. INITIAL DIAGNOSTIC
            $sentinelCtlPath = Get-SentinelCtlPath
            $initialStatusOutput = & $sentinelCtlPath status
            
            $isAgentLoaded = $initialStatusOutput | Select-String -Pattern "SentinelAgent is loaded" -Quiet
            $isAgentRunning = $initialStatusOutput | Select-String -Pattern "SentinelAgent is running as PPL" -Quiet
            
            # --- MODIFIED LOGIC (1 of 2) ---
            # Correctly handle "Disable State: Not disabled..." as a PASS condition.
            $disableLineMatch = $initialStatusOutput | Select-String -Pattern "Disable State:"
            $isAgentDisabled = $disableLineMatch -and ($disableLineMatch.Line -notlike "*Not disabled*")
            # --- END MODIFIED LOGIC ---
            
            $initialStatus = if ($isAgentLoaded -and $isAgentRunning -and -not $isAgentDisabled) { "[PASS]" } else { "[FAIL]" }

            Write-Host "Initial Parsed Status: $initialStatus"
            Write-Host "--- RAW 'sentinelctl status' OUTPUT (Initial Check) ---"
            $initialStatusOutput

            # 2. CONDITIONAL REMEDIATION (Corrected with Direct Invocation)
        if ($initialStatus -eq '[FAIL]') {
            Write-Warning "Agent status check failed. Attempting intelligent in-place remediation..."
            $pass = $using:Passphrase

            # Build Argument List as an array for cleaner handling by the call operator
            if ($isAgentDisabled) {
                $argumentList = @("enable_agent")
                Write-Verbose "Detected 'Disable State'. Attempting to re-enable with 'enable_agent' command..."
            } else {
                $argumentList = @("reload", "-a", "-k", "`"$pass`"")
                Write-Verbose "Detected a general service failure. Attempting to reload components..."
            }
    
            Write-Verbose "Executing: `"$sentinelCtlPath`" $($argumentList -join ' ')"
    
            # --- MODIFIED EXECUTION ---
            # Use the more direct call operator (&) instead of Start-Process.
            # Crucially, redirect the error stream (2) to the success stream (1) and capture all output.
            # This will show us any error messages printed by SentinelCtl.exe itself.
            $commandOutput = & $sentinelCtlPath $argumentList 2>&1 | Out-String

            if ($LASTEXITCODE -ne 0) {
                # Log the actual output from the failed command for diagnosis
                Write-Warning "Remediation command '$($argumentList[0])' failed. Raw output from SentinelCtl.exe follows:"
                Write-Warning $commandOutput
                throw "The remediation command '$($argumentList[0])' failed with exit code $LASTEXITCODE."
            }
            # --- END MODIFIED EXECUTION ---
    
            Write-Verbose "Remediation command completed successfully. Waiting 15 seconds for services to settle..."
            Start-Sleep -Seconds 15

    # ... final validation follows ...
}

            # If initial check passed, return success immediately.
            return @{ Status = "[PASS]"; Message = "Initial agent check passed, no action needed." }

        } catch {
            return @{ Status = "[FATAL]"; Message = "An unrecoverable error occurred inside the remote script block: $($_.Exception.Message)" }
        }
    }

    Write-Verbose "Final result from endpoint: $($finalResultObject | ConvertTo-Json -Depth 3 -Compress)"

    if ($finalResultObject.Status -eq '[FATAL]') {
        throw "The unified check/remediation script failed. Final Status: $($finalResultObject.Status). Message: $($finalResultObject.Message)"
    }
    
    Write-Host "--- Phase 1 Completed Successfully ---"
    Write-Host "Final Status: $($finalResultObject.Status)"
    return $true

} catch {
    Write-Error "A fatal, unrecoverable error occurred in the MetaScript: $_"
    return $null
}