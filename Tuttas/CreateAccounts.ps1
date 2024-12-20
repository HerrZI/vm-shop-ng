### PowerShell Script to Retrieve All Users from an Azure AD Group

# Connect to Azure AD
Connect-AzureAD

# Specify the Azure AD group name or object ID
$GroupName = "FIAE24J"
$domainID = "5b7e8018-d8bf-4e60-9f15-8d6083dbbfcb"
# Retrieve the group object
$Group = Get-AzureADGroup -Filter "DisplayName eq '$GroupName'"

if (!$Group) {
    Write-Output "Group not found!"
    exit
}

# Retrieve group members
$Members = Get-AzureADGroupMember -ObjectId $Group[0].ObjectId -All $true

# Display members
if ($Members) {
    $Members | Select-Object GivenName, Surname, UserPrincipalName | Format-Table -AutoSize
} else {
    Write-Output "No members found in the group."
}

$Members | Select-Object GivenName, Surname, UserPrincipalName | ForEach-Object {New-CloudStackAccount -AccountName $_.Surname.Replace(" ","_") -Email $_.UserPrincipalName -FirstName "$($_.GivenName.Replace(" ","_"))" -LastName $_.Surname -Username $_.Surname.Replace(" ","_") -Password "geheim" -DomainID $domainID} 
#Write-Output "Script completed!"
