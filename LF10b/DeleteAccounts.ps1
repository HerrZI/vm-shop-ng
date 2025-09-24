. .\Service.ps1

$data = $Global:data | select -Property Gruppe -Unique

$createdAccounts = @{}
Get-CloudStackAccounts -DomainID $Global:domainID | ForEach-Object { $createdAccounts[$_.Name] = $_}

# Durchlaufe die Daten und erstelle Accounts und Benutzer
foreach ($row in $data) {

    if ($row.Gruppe -eq $null) {
        continue
    }
    # Werte aus der Zeile
    $group = $row.Gruppe -replace '\s', ''
    # Account Loeschen
    Remove-CloudStackAccount -AccountID $createdAccounts[$group].Id -Confirm:$false
    try {
        Write-Host "Account '$group' wird gelöscht."
    } catch {
        Write-Error "Fehler beim Löschen des Accounts '$group'"
    }
}
