# Initialisiere Terraform
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Output "Das Skript läuft in: $ScriptDir"

set-Location $ScriptDir
Write-Host "Initialisiere Terraform"
terraform init

. .\Service.ps1

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
Get-CloudStackAccounts -DomainID $Global:domainID | ForEach-Object {$createdAccounts[$_.Name]=$_}

# Durchlaufe die Daten und erstelle Accounts und Benutzer
foreach ($row in $Global:data) {
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
            $groupMail = $group

            #Write-Host "New CloudSatck Account AccountName=$group DomainID=$Global:domainID AccountType=0 Email=$groupMail FirstName=Group LastName=$group UserName=$group Password=$groupPassword"
            $createAccountResult = New-CloudStackAccount -AccountName $group -DomainID $Global:domainID -AccountType 0 -Email $groupMail -FirstName "Group" -LastName $group -UserName $group -Password $groupPassword
            if ($createAccountResult) {
                $createdAccounts[$group] = $createAccountResult.ID
                Write-Host "Account '$group' erfolgreich erstellt."

                # Ermittle UserKey und Secret Key für den User
                $userid = $createAccountResult.user[0].id
                $keys = New-CloudStackApiKey -UserID $userid
                
                # Delete terraform state if exists
                if (Test-Path "terraform.tfstate") {
                    Remove-Item "terraform.tfstate"
                }

                terraform apply -var "api_key=$($keys.ApiKey)" -var "secret_key=$($keys.SecretKey)" -auto-approve
                if ($LASTEXITCODE -ne 0) {
                   Write-Error "Terraform apply failed"
                    exit 1
                }
                $output = terraform output -json | ConvertFrom-Json
                Write-Host "Infrastruktur aufgebaut, die öffentliche Adresse lautet: $($output.public_ip.value)"
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
            $newUserResult = New-CloudStackUser -Username $username -Password $userPassword -FirstName $firstname -LastName $lastname  -Email $email -AccountName $group -DomainID "$Global:domainID"

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
