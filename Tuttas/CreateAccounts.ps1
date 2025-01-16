$data = Import-Excel "d:\Temp\vm-shop-ng\Tuttas\Wahl.xlsx"
$domainID = "5b7e8018-d8bf-4e60-9f15-8d6083dbbfcb"
$groupPassword = "grouppassword"
$userPassword = "geheim"


# Funktion, um Benutzername aus der E-Mail-Adresse zu generieren
function Get-UsernameFromEmail {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Email
    )
    $Email = $Email -replace '\.', '_'
    return $Email.Split("@")[0]
}

# Liste der bereits erstellten Accounts (Gruppen)
$createdAccounts = @{}

# Durchlaufe die Daten und erstelle Accounts und Benutzer
foreach ($row in $data) {
    if ($row.Gruppe -eq $null) {
        continue
    }

    # Werte aus der Zeile
    $group = $row.Gruppe -replace '\s', ''
    $email = $row.'E-Mail-Adresse'
    $firstname = $row.Vorname  -replace ' ', '_'
    $lastname = $row.Nachname  -replace ' ', '_'
    $idNumber = $row.'ID-Nummer'
    $username = Get-UsernameFromEmail -Email $email
    $username = $username  -replace ' ', '_'

    

    # Prüfe, ob der Account für die Gruppe existiert
    if (-not $createdAccounts.ContainsKey($group)) {
        Write-Host "Erstelle Account für Gruppe: $group"

        # Account erstellen
        try {
            
            $createAccountResult = New-CloudStackAccount -AccountName $group -DomainID "$($domainID)" -AccountType "0" -Email "$($group)@mm-bbs.de" -FirstName "Group" -LastName $group -UserName $group -Password $groupPassword
            if ($createAccountResult) {
                $createdAccounts[$group] = $createAccountResult.ID
                Write-Host "Account '$group' erfolgreich erstellt."
            } else {
                Write-Warning "Account '$group' konnte nicht erstellt werden."
            }
        } catch {
            Write-Error "Fehler beim Erstellen des Accounts '$group'"
        }

    }

    # Benutzer dem entsprechenden Account hinzufügen
    $accountID = $createdAccounts[$group]
    Write-Host "Füge Benutzer '$username' zur Gruppe '$group' hinzu."

    try {
        #Write-Host "New CloudSatck User username=$username password=$userPassword Firstname=$firstname LastName=$lastname -Email $email -Accountname=$group -DomainID $domainID"
        $newUserResult = New-CloudStackUser -Username $username -Password $userPassword -FirstName $firstname -LastName $lastname  -Email $email -AccountName $group -DomainID "$domainID"

        if ($newUserResult) {
            Write-Host "Benutzer '$username' erfolgreich hinzugefügt."
        } else {
            Write-Warning "Benutzer '$username' konnte nicht hinzugefügt werden."
        }
    } catch {
        Write-Error "Fehler beim Hinzufügen von Benutzer '$username': $_"
    }
    
}
