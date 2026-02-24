# Define the group DN for the target group
$groupDN = "CN=ITS Workstations,OU=SCCM Groups,OU=Groups,DC=goodyearaz,DC=pri"

# Get all computers with "ITS -" or "IT -" in the Description field
$computers = Get-ADComputer -Filter {Description -like "*ITS -*" -or Description -like "*IT -*"} -Properties Description

# Display computers found with matching criteria
if ($computers.Count -gt 0) {
    Write-Output "Computers with 'ITS -' or 'IT -' in Description:"
    $computers | Select-Object Name, Description | Format-Table -AutoSize
} else {
    Write-Output "No computers found with 'ITS -' or 'IT -' in the Description field."
}

# Get the list of names of computers matching the criteria
$matchingComputerNames = $computers.Name

# Get current members of the AD group
$currentMembers = Get-ADGroupMember -Identity $groupDN -Recursive | Where-Object { $_.objectClass -eq "computer" }

# Display current group members
if ($currentMembers.Count -gt 0) {
    Write-Output "Current members of the group '$groupDN':"
    $currentMembers | Select-Object Name | Format-Table -AutoSize
} else {
    Write-Output "The group '$groupDN' currently has no members."
}

# Add computers that meet the criteria and aren't already members
$computersAdded = $false
foreach ($computer in $computers) {
    if ($currentMembers.Name -notcontains $computer.Name) {
        Add-ADGroupMember -Identity $groupDN -Members $computer -ErrorAction SilentlyContinue
        Write-Output "Added $($computer.Name) to $groupDN"
        $computersAdded = $true
    }
}
if (-not $computersAdded) {
    Write-Output "No computers were added to the group '$groupDN'."
}

# Remove computers that do not meet the criteria
$computersRemoved = $false
foreach ($member in $currentMembers) {
    # Retrieve the computer object and Description for each member
    $computerObj = Get-ADComputer -Identity $member.Name -Properties Description
    $description = $computerObj.Description

    # Check if Description does NOT contain "IT -" or "ITS -"
    if ($description -notlike "*ITS -*" -and $description -notlike "*IT -*") {
        Remove-ADGroupMember -Identity $groupDN -Members $member -Confirm:$false -ErrorAction SilentlyContinue
        Write-Output "Removed $($member.Name) from $groupDN due to mismatched description"
        $computersRemoved = $true
    }
}
if (-not $computersRemoved) {
    Write-Output "No computers were removed from the group '$groupDN'."
}