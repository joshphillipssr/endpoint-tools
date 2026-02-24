param(
    [Parameter(Mandatory = $true)]
    [string]$SearchBaseOu,

    [Parameter(Mandatory = $true)]
    [string]$GroupName
)

$ErrorActionPreference = 'Stop'

# Add all computers in the OU to the AD group.
Get-ADComputer -SearchBase $SearchBaseOu -Filter * | ForEach-Object {
    Add-ADGroupMember -Identity $GroupName -Members $_.DistinguishedName -ErrorAction SilentlyContinue
}

# Remove group members that are outside the OU scope.
$groupMembers = Get-ADGroupMember -Identity $GroupName
foreach ($member in $groupMembers) {
    if ($member.DistinguishedName -notlike "*$SearchBaseOu") {
        Remove-ADGroupMember -Identity $GroupName -Members $member.DistinguishedName -Confirm:$false
    }
}
