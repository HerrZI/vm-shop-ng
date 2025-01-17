if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    Install-Module -Name ImportExcel -Force -Scope CurrentUser
}
if (-not (Get-Module -ListAvailable -Name CSHelper)) {
    Install-Module -Name CSHelper -Force -Scope CurrentUser
}

if (-not $Global:CloudStackBaseUrl -or -not $Global:CloudStackApiKey -or -not $Global:CloudStackSecretKey) {
    $ApiKey = Read-Host "Bitte geben Sie den CloudStack API-Key ein: "
    $Secret = Read-Host "Bitte geben Sie den CloudStack Secret-Key ein: "
    $url = "https://cloudstack.mm-bbs.de/client/api"
    Connect-CloudStack -BaseUrl $url -ApiKey $ApiKey -SecretKey $Secret        
    if (-not $Global:CloudStackBaseUrl -or -not $Global:CloudStackApiKey -or -not $Global:CloudStackSecretKey) {
        Write-Error "Fehler beim Verbinden mit CloudStack."
        exit
    }
}


# Abfrage des Pfades mit variable als Default-Wert
$pfad = Read-Host "Bitte geben Sie den Pfad zur Excel-Datei ein [Bsp.: d:\Temp\vm-shop-ng\Tuttas\Wahl.xlsx]: "
if ($pfad -eq "") {
    $pfad = "d:\Temp\vm-shop-ng\Tuttas\Wahl.xlsx"
}
if (-not (Test-Path $pfad)) {
    Write-Error "Datei '$pfad' existiert nicht."
    exit
} 
$data = Import-Excel $pfad


$domainID = Read-Host "Bitte geben Sie die Domain-ID ein [z.B. 5b7e8018-d8bf-4e60-9f15-8d6083dbbfcb]: "
if ($domainID -eq "") {
    $domainID = "5b7e8018-d8bf-4e60-9f15-8d6083dbbfcb"
}

$groupPassword = "grouppassword" # Passwort für den Account (die Gruppe)
$userPassword = "geheim" # Passwort für den User


# Funktion, um Benutzername aus der E-Mail-Adresse zu generieren
function Get-UsernameFromEmail {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Email
    )
    return $Email.Split("@")[0]
}

# Liste der bereits erstellten Accounts (Gruppen)
$createdAccounts = @{}
Get-CloudStackAccounts -DomainID $domainID | ForEach-Object {$createdAccounts[$_.Name]=$_}

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
        Write-Host "Erstelle Account für Gruppe: ($group)"

        # Account erstellen
        try {
            $groupMail = $group + "@mm-bbs.de"
            #Write-Host "New CloudSatck Account AccountName=$group DomainID=$domainID AccountType=0 Email=$groupMail FirstName=Group LastName=$group UserName=$group Password=$groupPassword"
            $createAccountResult = New-CloudStackAccount -AccountName $group -DomainID "$($domainID)" -AccountType 0 -Email $groupMail -FirstName "Group" -LastName $group -UserName $group -Password $groupPassword
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
    else {
        Write-Warning "Account für Gruppe: $group existiert bereits"
    }

    # Benutzer dem entsprechenden Account hinzufügen
    $accountID = $createdAccounts[$group]

    $userList = @{}
    Get-CloudStackUsers -AccountName $group -DomainID $domainID | ForEach-Object {$userList[$_.Username]=$_}


    if (-not $userList.ContainsKey($username)) {
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
            #Write-Error "Fehler beim Hinzufügen von Benutzer '$username': $_"
        }
    }
    else {
        Write-Warning "Benutzer $username existiert bereits in der Gruppe $group"
    }
    
}
