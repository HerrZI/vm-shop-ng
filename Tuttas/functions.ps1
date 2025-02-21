function Get-SignedUrl {
    param (
        [Parameter(Mandatory = $false)]
        [string]$BaseUrl,      # Basis-URL der CloudStack API (optional)

        [Parameter(Mandatory = $false)]
        [string]$ApiKey,       # API-Schlüssel (optional)

        [Parameter(Mandatory = $false)]
        [string]$SecretKey,    # Geheimschlüssel (optional)

        [Parameter(Mandatory = $true)]
        [hashtable]$Parameters # API-Parameter
    )

    # Globale Variablen verwenden, falls keine Parameter übergeben wurden
    if (-not $BaseUrl) {
        if ($Global:CloudStackBaseUrl) {
            $BaseUrl = $Global:CloudStackBaseUrl
        } else {
            throw "Basis-URL nicht angegeben und keine globale Variable vorhanden."
        }
    }

    #Write-Host $BaseUrl

    if (-not $ApiKey) {
        if ($Global:CloudStackApiKey) {
            $ApiKey = $Global:CloudStackApiKey
        } else {
            throw "API-Schlüssel nicht angegeben und keine globale Variable vorhanden."
        }
    }

    if (-not $SecretKey) {
        if ($Global:CloudStackSecretKey) {
            $SecretKey = $Global:CloudStackSecretKey
        } else {
            throw "Secret-Key nicht angegeben und keine globale Variable vorhanden."
        }
    }

    # Kopiere die Schlüssel in eine separate Liste
    $keyList = $Parameters.Keys | ForEach-Object { $_ }

    # Werte URL-dekodieren
    foreach ($key in $keyList) {
        $Parameters[$key] = [System.Web.HttpUtility]::UrlEncode($Parameters[$key])
    }

    $Parameters["apikey"] = $ApiKey
    $Parameters["response"] = "json"

    # Sortiere die Parameter alphabetisch
    $SortedParams = $Parameters.GetEnumerator() | Sort-Object Name
    $QueryString = $SortedParams.ForEach({ "$($_.Name)=$($_.Value)" }) -join "&"

    #Write-Host "Query String:"+$QueryString 
    #Write-Host "Secret Key"+$SecretKey

    # Signiere die Anfrage
    $Encoding = [System.Text.Encoding]::UTF8
    $HmacSha1 = New-Object System.Security.Cryptography.HMACSHA1
    $HmacSha1.Key = $Encoding.GetBytes($SecretKey)

    # ComputeHash benötigt ein Byte-Array
    $HashBytes = $HmacSha1.ComputeHash($Encoding.GetBytes($QueryString.ToLower()))

    # Signatur in Base64 kodieren
    $Signature = [System.Convert]::ToBase64String($HashBytes)

    # URL-Kodierung mit [System.Net.WebUtility]
    $EncodedSignature = [System.Net.WebUtility]::UrlEncode($Signature)

    # Finale URL korrekt zusammensetzen
    $FinalUrl = "$($BaseUrl)?$QueryString&signature=$EncodedSignature"

    return $FinalUrl
}

function Wait-CloudStackJob {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$JobId # Die ID des Jobs, auf den gewartet werden soll
    )

    try {
        # API-Parameter für die Abfrage des Job-Status
        $Parameters = @{
            "command" = "queryAsyncJobResult"
            "jobid"   = $JobId
        }

        # Job-Status abfragen
        while ($true) {
            $SignedUrl = Get-SignedUrl -Parameters $Parameters
            $Response = Invoke-RestMethod -Uri $SignedUrl -Method Get

            if ($Response.queryasyncjobresultresponse.jobstatus -ne 0) {
                # Job abgeschlossen
                return $Response.queryasyncjobresultresponse
            }

            # Warte, bevor die Anfrage wiederholt wird
            Start-Sleep -Seconds 5
        }
    } catch {
        Write-Error "Fehler beim Abfragen des Job-Status für Job-ID '$JobId': $_"
    }
}


<#
.SYNOPSIS
    Verbindet das Skript mit einer CloudStack-Instanz.
.DESCRIPTION
    Diese Funktion stellt eine Verbindung zu einer CloudStack-Instanz her und speichert die Anmeldedaten als globale Variablen.
.PARAMETER BaseUrl
    Die Basis-URL der CloudStack API.
.PARAMETER ApiKey
    Der API-Schlüssel für die Authentifizierung.
.PARAMETER SecretKey
    Der geheime Schlüssel für die Authentifizierung.
.EXAMPLE
    Connect-CloudStack -BaseUrl "https://cloudstack.mm-bbs.de/client/api" -ApiKey "APIKEY" -SecretKey "SecretKey"
#>
function Connect-CloudStack {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,   # Basis-URL der CloudStack API

        [Parameter(Mandatory = $true)]
        [string]$ApiKey,    # API-Schlüssel

        [Parameter(Mandatory = $true)]
        [string]$SecretKey  # Geheimschlüssel (Secret Key)
    )

    # Funktion zur Signierung der Anfrage
    

    try {
        # Teste Verbindung mit listUsers
        $Parameters = @{ "command" = "listProjects" }
        $SignedUrl = Get-SignedUrl -BaseUrl $BaseUrl -ApiKey $ApiKey -SecretKey $SecretKey -Parameters $Parameters
        #Write-Host "Generierte URL: $SignedUrl"
        $Response = Invoke-RestMethod -Uri $SignedUrl -Method Get

        #Write-Host "Response: $($Response)"

        if ($Response) {
            # Benutzerinformationen extrahieren
            Write-Host "Erfolgreich mit CloudStack verbunden!" -ForegroundColor Green
            
            # Anmeldedaten als globale Variablen speichern
            Set-Variable -Name "CloudStackBaseUrl" -Value $BaseUrl -Scope Global
            Set-Variable -Name "CloudStackApiKey" -Value $ApiKey -Scope Global
            Set-Variable -Name "CloudStackSecretKey" -Value $SecretKey -Scope Global
            Set-Variable -Name "CloudStackUserName" -Value $UserName -Scope Global
        } else {
            Write-Error "Fehler: Keine Benutzerinformationen gefunden."
        }
    } catch {
        Write-Error "Fehler bei der Verbindung: $_"
    }
}

<#
.SYNOPSIS
    Erstellt ein neues CloudStack-Projekt.
.DESCRIPTION
    Diese Funktion erstellt ein neues Projekt in CloudStack.
.PARAMETER Name
    Der Name des Projekts.
.PARAMETER DisplayText
    Die optionale Beschreibung des Projekts.
.PARAMETER Account
    Der Account, dem das Projekt zugewiesen werden soll.
.PARAMETER Domain
    Die optionale Domäne, der das Projekt zugewiesen werden soll.
.EXAMPLE
    New-CloudStackProject -Name "Projekt1" -Domain "example.com"
.ExAMPLE
    "A","B","C" | New-cloudStackProject
    Legt die Projekte A,B,C an
#>
function New-CloudStackProject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Name, # Name des Projekts

        [Parameter(Mandatory = $false)]
        [string]$DisplayText, # Optional: Beschreibung des Projekts

        [Parameter(Mandatory = $false)]
        [string]$Account, # Optional: Account, dem das Projekt zugewiesen werden soll

        [Parameter(Mandatory = $false)]
        [string]$DomainID        # Optional: Domain-ID, der das Projekt zugewiesen werden soll
    )

    begin {
        # Globale Variablen prüfen
        if (-not $Global:CloudStackBaseUrl -or -not $Global:CloudStackApiKey -or -not $Global:CloudStackSecretKey) {
            throw "Bitte zuerst Connect-CloudStack ausführen, um eine Verbindung zu CloudStack herzustellen."
        }
    }

    process {
        try {
            # API-Parameter für die Erstellung des Projekts
            $Parameters = @{
                "command" = "createProject"
                "name"    = $Name
            }
            if ($DisplayText) {
                $Parameters["displaytext"] = $DisplayText
            }
            if ($Account) {
                $Parameters["account"] = $Account
            }
            if ($DomainID) {
                $Parameters["domainid"] = $DomainID   # Korrekte Parameterübergabe
            }

            # Signierte URL erstellen
            $SignedUrl = Get-SignedUrl -Parameters $Parameters

            #Write-Host "Signierte URL: $SignedUrl" -ForegroundColor Yellow

            # Anfrage an die API senden
            $Response = Invoke-RestMethod -Uri $SignedUrl -Method Get

            # Überprüfung der Antwort auf Job-ID
            if ($Response.createprojectresponse.jobid) {
                $JobId = $Response.createprojectresponse.jobid
                Write-Host "Projekt '$Name' angelegt. Warte auf Abschluss des Jobs ($JobId)..." -ForegroundColor Yellow

                # Warte auf Job-Ergebnis
                $JobResult = Wait-CloudStackJob -JobId $JobId

                # Überprüfe das Ergebnis
                if ($JobResult.jobstatus -eq 1) {
                    Write-Host "Projekt '$Name' erfolgreich erstellt." -ForegroundColor Green
                    return $JobResult.jobresult.project
                }
                else {
                    throw "Fehler bei der Projekterstellung. Job-Status: $($JobResult.jobstatus)"
                }
            }
            else {
                throw "Keine Job-ID erhalten. API-Antwort: $($Response | ConvertTo-Json -Depth 10)"
            }
        }
        catch {
            Write-Error "Fehler beim Erstellen des Projekts '$Name': $_"
        }
    }
}


<#
.SYNOPSIS
    Listet alle CloudStack-Projekte auf.

.DESCRIPTION
    Diese Funktion listet alle Projekte in CloudStack auf.
.PARAMETER DomainId
    Die ID der Domain, nach der gefiltert werden soll.
.PARAMETER Account
    Der Account, nach dem gefiltert werden soll.
.PARAMETER Name
    Der Name des Projekts, nach dem gefiltert werden soll.
.EXAMPLE
    Get-CloudStackProjects
.EXAMPLE
    Get-CloudStackProjects -Name "Projekt1"

#>
function Get-CloudStackProjects {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$DomainId,   # Optional: Filter nach Domain-ID

        [Parameter(Mandatory = $false)]
        [string]$Account,    # Optional: Filter nach Account

        [Parameter(Mandatory = $false)]
        [switch]$ListAll,     # Optional: Alle Projekte anzeigen

        [Parameter(Mandatory = $false)]
        [string]$Name        # Optional: Filter nach Projektname
    )

    begin {
        # Globale Variablen prüfen
        if (-not $Global:CloudStackBaseUrl -or -not $Global:CloudStackApiKey -or -not $Global:CloudStackSecretKey) {
            throw "Bitte zuerst Connect-CloudStack ausführen, um eine Verbindung zu CloudStack herzustellen."
        }
    }

    process {
        try {
            # API-Parameter für die Projektsuche
            $Parameters = @{ "command" = "listProjects" }

            if ($DomainId) {
                $Parameters["domainid"] = $DomainId
            }
            if ($Account) {
                $Parameters["account"] = $Account
            }
            if ($ListAll) {
                $Parameters["listall"] = "true"
            }
             if ($Name) {
                $Parameters["name"] = $Name
            }

            # Signierte URL erstellen
            $SignedUrl = Get-SignedUrl -Parameters $Parameters

            # Anfrage an die API senden
            $Response = Invoke-RestMethod -Uri $SignedUrl -Method Get

            # Überprüfung der Antwort
            if ($Response.listprojectsresponse.project) {
                $Response.listprojectsresponse.project | ForEach-Object {
                    [PSCustomObject]@{
                        ID          = $_.id
                        Name        = $_.name
                        DisplayText = $_.displaytext
                        Account     = $_.account
                        Domain      = $_.domain
                        State       = $_.state
                    }
                }
            } else {
                Write-Warning "Keine Projekte gefunden."
            }
        } catch {
            Write-Error "Fehler beim Abrufen der Projekte: $_"
        }
    }
}

<#
.SYNOPSIS
    Löscht ein CloudStack-Projekt.  
.DESCRIPTION
    Diese Funktion löscht ein Projekt in CloudStack.
.PARAMETER ID
    Die ID des zu löschenden Projekts.
.EXAMPLE
    Remove-CloudStackProject -ID "1234"
.EXAMPLE
    get-cloudStackProjects | Select-Object -ExpandProperty ID | Remove-CloudStackProject
    Löscht alle Projekte

#>
function Remove-CloudStackProject {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$ID   # ID des zu löschenden Projekts
    )

    begin {
        # Globale Variablen prüfen
        if (-not $Global:CloudStackBaseUrl -or -not $Global:CloudStackApiKey -or -not $Global:CloudStackSecretKey) {
            throw "Bitte zuerst Connect-CloudStack ausführen, um eine Verbindung zu CloudStack herzustellen."
        }
    }

    process {
        try {
            # Bestätigungsdialog
            if ($PSCmdlet.ShouldProcess("Projekt mit ID '$ID'", "Löschen")) {
                # API-Parameter für das Löschen eines Projekts
                $Parameters = @{
                    "command" = "deleteProject"
                    "id"      = $ID
                }

                # Signierte URL erstellen
                $SignedUrl = Get-SignedUrl -Parameters $Parameters

                # Anfrage an die API senden
                $Response = Invoke-RestMethod -Uri $SignedUrl -Method Get

                # Überprüfung der Antwort
                if ($Response.deleteprojectresponse.jobid) {
                    $JobId = $Response.deleteprojectresponse.jobid
                    Write-Host "Löschen von Projekt '$ID' gestartet. Warte auf Abschluss des Jobs ($JobId)..." -ForegroundColor Yellow

                    # Warte auf Job-Ergebnis
                    $JobResult = Wait-CloudStackJob -JobId $JobId

                    # Überprüfe das Ergebnis
                    if ($JobResult.jobstatus -eq 1) {
                        Write-Host "Projekt '$ID' erfolgreich gelöscht." -ForegroundColor Green
                    } else {
                        throw "Fehler beim Löschen des Projekts. Job-Status: $($JobResult.jobstatus)"
                    }
                } else {
                    throw "Keine Job-ID erhalten. API-Antwort: $($Response | ConvertTo-Json -Depth 10)"
                }
            }
        } catch {
            Write-Error "Fehler beim Löschen des Projekts '$ProjectId': $_"
        }
    }
}

<#
.SYNOPSIS
    Fügt einen Benutzer zu einem CloudStack-Projekt hinzu.
.DESCRIPTION
    Diese Funktion fügt einen Benutzer zu einem Projekt in CloudStack hinzu.
.PARAMETER ProjectId
    Die ID des Projekts, dem der Benutzer hinzugefügt werden soll.
.PARAMETER Username
    Der Benutzername des hinzuzufügenden Benutzers.
.EXAMPLE
    Add-CloudStackProjectMember -ProjectId "1234" -Username "user1"
#>
function Add-CloudStackProjectMember {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ProjectId,    # ID des Projekts, dem der Benutzer hinzugefügt werden soll

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Username      # Benutzername des hinzuzufügenden Benutzers
    )

    begin {
        # Globale Variablen prüfen
        if (-not $Global:CloudStackBaseUrl -or -not $Global:CloudStackApiKey -or -not $Global:CloudStackSecretKey) {
            throw "Bitte zuerst Connect-CloudStack ausführen, um eine Verbindung zu CloudStack herzustellen."
        }
    }

    process {
        try {
            # API-Parameter für das Hinzufügen eines Benutzers
            $Parameters = @{
                "command"   = "addAccountToProject"
                "projectid" = $ProjectId
                "account"   = $Username
            }

            # Signierte URL erstellen
            $SignedUrl = Get-SignedUrl -Parameters $Parameters

            # Anfrage an die API senden
            $Response = Invoke-RestMethod -Uri $SignedUrl -Method Get

            # Überprüfung der Antwort auf Job-ID
            if ($Response.addaccounttoprojectresponse.jobid) {
                $JobId = $Response.addaccounttoprojectresponse.jobid
                Write-Host "Hinzufügen von Benutzer '$Username' zu Projekt '$ProjectId' gestartet. Warte auf Abschluss des Jobs ($JobId)..." -ForegroundColor Yellow

                # Warte auf Job-Ergebnis
                $JobResult = Wait-CloudStackJob -JobId $JobId

                # Überprüfe das Ergebnis
                if ($JobResult.jobstatus -eq 1) {
                    Write-Host "Benutzer '$Username' erfolgreich zum Projekt '$ProjectId' hinzugefügt." -ForegroundColor Green
                } else {
                    throw "Fehler beim Hinzufügen des Benutzers. Job-Status: $($JobResult.jobstatus)"
                }
            } else {
                throw "Keine Job-ID erhalten. API-Antwort: $($Response | ConvertTo-Json -Depth 10)"
            }
        } catch {
            Write-Error "Fehler beim Hinzufügen des Benutzers '$Username' zum Projekt '$ProjectId': $_"
        }
    }
}

<#
.SYNOPSIS
    Entfernt einen Benutzer aus einem CloudStack-Projekt.   
.DESCRIPTION
    Diese Funktion entfernt einen Benutzer aus einem Projekt in CloudStack.
.PARAMETER ProjectId
    Die ID des Projekts, aus dem der Benutzer entfernt werden soll.
.PARAMETER Username
    Der Benutzername des zu entfernenden Benutzers.
.EXAMPLE
    Remove-CloudStackProjectMember -ProjectId "1234" -Username "user1"
#>
function Remove-CloudStackProjectMember {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ProjectId,    # ID des Projekts, aus dem der Benutzer entfernt werden soll

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Username      # Benutzername des zu entfernenden Benutzers
    )

    begin {
        # Globale Variablen prüfen
        if (-not $Global:CloudStackBaseUrl -or -not $Global:CloudStackApiKey -or -not $Global:CloudStackSecretKey) {
            throw "Bitte zuerst Connect-CloudStack ausführen, um eine Verbindung zu CloudStack herzustellen."
        }
    }

    process {
        try {
            # Bestätigungsdialog
            if ($PSCmdlet.ShouldProcess("Benutzer '$Username' aus Projekt '$ProjectId'", "Entfernen")) {
                # API-Parameter für das Entfernen eines Benutzers
                $Parameters = @{
                    "command"   = "deleteAccountFromProject"
                    "projectid" = $ProjectId
                    "account"   = $Username
                }

                # Signierte URL erstellen
                $SignedUrl = Get-SignedUrl -Parameters $Parameters

                # Anfrage an die API senden
                $Response = Invoke-RestMethod -Uri $SignedUrl -Method Get

                # Überprüfung der Antwort auf Job-ID
                if ($Response.deleteaccountfromprojectresponse.jobid) {
                    $JobId = $Response.deleteaccountfromprojectresponse.jobid
                    Write-Host "Entfernen von Benutzer '$Username' aus Projekt '$ProjectId' gestartet. Warte auf Abschluss des Jobs ($JobId)..." -ForegroundColor Yellow

                    # Warte auf Job-Ergebnis
                    $JobResult = Wait-CloudStackJob -JobId $JobId

                    # Überprüfe das Ergebnis
                    if ($JobResult.jobstatus -eq 1) {
                        Write-Host "Benutzer '$Username' erfolgreich aus Projekt '$ProjectId' entfernt." -ForegroundColor Green
                    } else {
                        throw "Fehler beim Entfernen des Benutzers. Job-Status: $($JobResult.jobstatus)"
                    }
                } else {
                    throw "Keine Job-ID erhalten. API-Antwort: $($Response | ConvertTo-Json -Depth 10)"
                }
            }
        } catch {
            Write-Error "Fehler beim Entfernen des Benutzers '$Username' aus Projekt '$ProjectId': $_"
        }
    }
}

<#
.SYNOPSIS
    Überprüft, ob ein CloudStack-Projekt existiert.
.DESCRIPTION
    Diese Funktion überprüft, ob ein Projekt in CloudStack existiert.
.PARAMETER ProjectId
    Die ID des Projekts.
.PARAMETER ProjectName
    Der Name des Projekts.
.EXAMPLE
    Test-CloudStackProject -ProjectId "1234"
.EXAMPLE
    Test-CloudStackProject -ProjectName "Projekt1"
#>
function Test-CloudStackProject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$ProjectId, # Optional: ID des Projekts

        [Parameter(Mandatory = $false)]
        [string]$ProjectName  # Optional: Name des Projekts
    )

    begin {
        # Globale Variablen prüfen
        if (-not $Global:CloudStackBaseUrl -or -not $Global:CloudStackApiKey -or -not $Global:CloudStackSecretKey) {
            throw "Bitte zuerst Connect-CloudStack ausführen, um eine Verbindung zu CloudStack herzustellen."
        }

        # Sicherstellen, dass mindestens ein Parameter angegeben ist
        if (-not $ProjectId -and -not $ProjectName) {
            throw "Entweder 'ProjectId' oder 'ProjectName' muss angegeben werden."
        }
    }

    process {
        try {
            # API-Parameter für die Projektsuche
            $Parameters = @{ "command" = "listProjects" }
            if ($ProjectId) {
                $Parameters["id"] = $ProjectId
            }
            if ($ProjectName) {
                $Parameters["name"] = $ProjectName
            }

            # Signierte URL erstellen
            $SignedUrl = Get-SignedUrl -Parameters $Parameters

            # Anfrage an die API senden
            $Response = Invoke-RestMethod -Uri $SignedUrl -Method Get

            # Überprüfung der Antwort
            if ($Response.listprojectsresponse.project -and $Response.listprojectsresponse.project.Count -gt 0) {
                Write-Host "Projekt gefunden:" -ForegroundColor Green
                $Response.listprojectsresponse.project | ForEach-Object {
                    [PSCustomObject]@{
                        ID          = $_.id
                        Name        = $_.name
                        DisplayText = $_.displaytext
                        State       = $_.state
                    }
                }
                return $true
            }
            else {
                Write-Host "Projekt nicht gefunden." -ForegroundColor Yellow
                return $false
            }
        }
        catch {
            Write-Error "Fehler beim Überprüfen des Projekts: $_"
            return $false
        }
    }
}

<#
.SYNOPSIS
    Gibt die Benutzer eines CloudStack-Projekts zurück. 
.DESCRIPTION
    Diese Funktion gibt die Benutzer eines Projekts in CloudStack zurück.
.PARAMETER ProjectId
    Die ID des Projekts, dessen Benutzer abgefragt werden sollen.
.EXAMPLE
    Get-CloudStackProjectMember -ProjectId "1234"

#>
function Get-CloudStackProjectMember {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ProjectId   # ID des Projekts, dessen Benutzer abgefragt werden sollen
    )

    begin {
        # Globale Variablen prüfen
        if (-not $Global:CloudStackBaseUrl -or -not $Global:CloudStackApiKey -or -not $Global:CloudStackSecretKey) {
            throw "Bitte zuerst Connect-CloudStack ausführen, um eine Verbindung zu CloudStack herzustellen."
        }
    }

    process {
        try {
            # API-Parameter für die Abfrage der Benutzer eines Projekts
            $Parameters = @{
                "command"   = "listProjectAccounts"
                "projectid" = $ProjectId
            }

            # Signierte URL erstellen
            $SignedUrl = Get-SignedUrl -Parameters $Parameters

            # Anfrage an die API senden
            $Response = Invoke-RestMethod -Uri $SignedUrl -Method Get

            # Überprüfung der Antwort
            if ($Response.listprojectaccountsresponse.projectaccount -and $Response.listprojectaccountsresponse.projectaccount.Count -gt 0) {
                Write-Host "Benutzer im Projekt '$ProjectId':" -ForegroundColor Green
                $Response.listprojectaccountsresponse.projectaccount | ForEach-Object {
                    [PSCustomObject]@{
                        Username = $_.account
                        Role     = $_.role
                        State    = $_.state
                    }
                }
            }
            else {
                Write-Warning "Keine Benutzer im Projekt '$ProjectId' gefunden."
            }
        }
        catch {
            Write-Error "Fehler beim Abrufen der Benutzer für Projekt '$ProjectId': $_"
        }
    }
}

<#
.SYNOPSIS
    Erstellt einen neuen CloudStack-Account.
.DESCRIPTION
    Diese Funktion erstellt einen neuen Account in CloudStack.
.PARAMETER AccountName
    Der Name des neuen Accounts.
.PARAMETER Email
    Die E-Mail-Adresse des neuen Accounts.
.PARAMETER FirstName
    Der Vorname des Accountinhabers.
.PARAMETER LastName
    Der Nachname des Accountinhabers.
.PARAMETER Username
    Der Benutzername des neuen Accounts.
.PARAMETER Password
    Das Passwort des neuen Accounts.
.PARAMETER DomainID
    Die ID der Domain, zu der der Account hinzugefügt werden soll.
.PARAMETER AccountType
    Der Typ des Accounts: 0 = User, 1 = Admin, 2 = Domain-Admin (Standard: 0)
.EXAMPLE
    New-CloudStackAccount -AccountName "Account1" -Email "test@test.de" -FirstName "Max" -LastName "Mustermann" -Username "user1" -Password "password" -DomainID "1234"

#>
function New-CloudStackAccount {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccountName,    # Name des neuen Accounts

        [Parameter(Mandatory = $true)]
        [string]$Email,          # Email des Accounts

        [Parameter(Mandatory = $true)]
        [string]$FirstName,      # Vorname des Accountinhabers

        [Parameter(Mandatory = $true)]
        [string]$LastName,       # Nachname des Accountinhabers

        [Parameter(Mandatory = $true)]
        [string]$Username,       # Benutzername

        [Parameter(Mandatory = $true)]
        [string]$Password,       # Passwort

        [Parameter(Mandatory = $true)]
        [string]$DomainID, 

        [Parameter(Mandatory = $false)]
        [string]$AccountType = "0"  # Typ des Accounts: 0 = User, 1 = Admin, 2 = Domain-Admin
    )

    begin {
        # Überprüfe globale Variablen
        if (-not $Global:CloudStackBaseUrl -or -not $Global:CloudStackApiKey -or -not $Global:CloudStackSecretKey) {
            throw "Bitte zuerst Connect-CloudStack ausführen, um eine Verbindung zu CloudStack herzustellen."
        }

        if (-not $DomainID) {
            throw "DomainID ist erforderlich. Bitte angeben oder setzen Sie die globale Variable 'CloudStackDomainID'."
        }
    }

    process {
        try {
            # API-Parameter definieren
            $Parameters = @{
                "command"     = "createAccount"
                "account"     = $AccountName
                "email"       = $Email
                "firstname"   = $FirstName
                "lastname"    = $LastName
                "username"    = $Username
                "password"    = $Password
                "domainid"    = $DomainID
                "accounttype" = $AccountType
                "response"    = "json"
            }

            # Signierte URL erstellen
            $SignedUrl = Get-SignedUrl -Parameters $Parameters

            Write-Host $SignedUrl -ForegroundColor yell

            # Anfrage senden
            $Response = Invoke-RestMethod -Uri $SignedUrl -Method Get

            # Überprüfe API-Antwort
            if ($Response.createaccountresponse) {
                Write-Host "Account '$AccountName' erfolgreich erstellt!" -ForegroundColor Green
                return $Response.createaccountresponse.account
            } else {
                throw "Fehler beim Erstellen des Accounts: $($Response | ConvertTo-Json -Depth 10)"
            }
        } catch {
            Write-Error "Fehler beim Erstellen des Accounts '$AccountName': $_"
        }
    }
}

<#
.SYNOPSIS
    Gibt alle CloudStack-Accounts zurück.
.DESCRIPTION
    Diese Funktion gibt alle Accounts in CloudStack zurück.
.PARAMETER DomainID
    Die ID der Domain, nach der gefiltert werden soll.
.PARAMETER ListAll
    Gibt alle Accounts zurück, unabhängig von den Zugriffsrechten.
.EXAMPLE
    Get-CloudStackAccounts -DomainID "1234"
#>
function Get-CloudStackAccounts {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$DomainID,  # Optional: Filter nach einer bestimmten DomainID

        [Parameter(Mandatory = $false)]
        [switch]$ListAll    # Optional: Alle Accounts unabhängig von Zugriff
    )

    begin {
        # Überprüfe globale Variablen
        if (-not $Global:CloudStackBaseUrl -or -not $Global:CloudStackApiKey -or -not $Global:CloudStackSecretKey) {
            throw "Bitte zuerst Connect-CloudStack ausführen, um eine Verbindung zu CloudStack herzustellen."
        }
    }

    process {
        try {
            # API-Parameter definieren
            $Parameters = @{
                "command"  = "listAccounts"
                "response" = "json"
            }

            if ($DomainID) {
                $Parameters["domainid"] = $DomainID
            }

            if ($ListAll) {
                $Parameters["listall"] = "true"
            }

            # Signierte URL erstellen
            $SignedUrl = Get-SignedUrl -Parameters $Parameters

            # Anfrage senden
            $Response = Invoke-RestMethod -Uri $SignedUrl -Method Get

            # Überprüfung der API-Antwort
            if ($Response.listaccountsresponse.account) {
                $Accounts = $Response.listaccountsresponse.account
                # Gib die Accounts als PowerShell-Objekte zurück
                $Accounts | ForEach-Object {
                    [PSCustomObject]@{
                        ID          = $_.id
                        Name        = $_.name
                        Type        = if ($_.accounttype -eq 1) { "Admin" } elseif ($_.accounttype -eq 2) { "Domain Admin" } else { "User" }
                        DomainID    = $_.domainid
                        DomainName  = $_.domain
                        Email       = $_.email
                        State       = $_.state
                    }
                }
            } else {
                Write-Warning "Keine Accounts gefunden."
            }
        } catch {
            Write-Error "Fehler beim Abrufen der Accounts: $_"
        }
    }
}

<#
.SYNOPSIS
    Löscht einen CloudStack-Account.
.DESCRIPTION
    Diese Funktion löscht einen Account in CloudStack.
.PARAMETER AccountID
    Die ID des zu löschenden Accounts.
.EXAMPLE
    Remove-CloudStackAccount -AccountID "1234"
#>
function Remove-CloudStackAccount {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$AccountID  # Die ID des zu löschenden Accounts
    )

    begin {
        # Überprüfe globale Variablen
        if (-not $Global:CloudStackBaseUrl -or -not $Global:CloudStackApiKey -or -not $Global:CloudStackSecretKey) {
            throw "Bitte zuerst Connect-CloudStack ausführen, um eine Verbindung zu CloudStack herzustellen."
        }
    }

    process {
        try {
            # Bestätigungsdialog
            if ($PSCmdlet.ShouldProcess("Account mit ID '$AccountID'", "Löschen")) {
                # API-Parameter definieren
                $Parameters = @{
                    "command"  = "deleteAccount"
                    "id"       = $AccountID
                    "response" = "json"
                }

                # Signierte URL erstellen
                $SignedUrl = Get-SignedUrl -Parameters $Parameters

                # Anfrage senden
                $Response = Invoke-RestMethod -Uri $SignedUrl -Method Get

                # Überprüfung der API-Antwort
                if ($Response.deleteaccountresponse) {
                    Write-Host "Account mit ID '$AccountID' erfolgreich gelöscht." -ForegroundColor Green
                } else {
                    throw "Fehler beim Löschen des Accounts: $($Response | ConvertTo-Json -Depth 10)"
                }
            }
        } catch {
            Write-Error "Fehler beim Löschen des Accounts mit ID '$AccountID': $_"
        }
    }
}

<#
.SYNOPSIS
    Gibt alle CloudStack-Benutzer zurück.
.DESCRIPTION
    Diese Funktion gibt alle Benutzer in CloudStack zurück.
.PARAMETER AccountName
    Der Name des Accounts, nach dem gefiltert werden soll.
.PARAMETER DomainID
    Die ID der Domain, nach der gefiltert werden soll.
.EXAMPLE
    Get-CloudStackUsers
.EXAMPLE
    Get-CloudStackUsers -AccountName "Account1"
#>
function Get-CloudStackUsers {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$AccountName,  # Optional: Filter nach einem bestimmten Account

        [Parameter(Mandatory = $false)]
        [string]$DomainID      # Optional: Filter nach einer spezifischen Domain
    )

    begin {
        # Überprüfe globale Variablen
        if (-not $Global:CloudStackBaseUrl -or -not $Global:CloudStackApiKey -or -not $Global:CloudStackSecretKey) {
            throw "Bitte zuerst Connect-CloudStack ausführen, um eine Verbindung zu CloudStack herzustellen."
        }
    }

    process {
        try {
            # API-Parameter definieren
            $Parameters = @{
                "command"  = "listUsers"
                "response" = "json"
            }

            if ($AccountName) {
                $Parameters["account"] = $AccountName
            }

            if ($DomainID) {
                $Parameters["domainid"] = $DomainID
            }

            # Signierte URL erstellen
            $SignedUrl = Get-SignedUrl -Parameters $Parameters

            # Anfrage senden
            $Response = Invoke-RestMethod -Uri $SignedUrl -Method Get

            # Überprüfung der API-Antwort
            if ($Response.listusersresponse.user) {
                $Users = $Response.listusersresponse.user
                # Gib die Benutzer als PowerShell-Objekte zurück
                $Users | ForEach-Object {
                    [PSCustomObject]@{
                        ID         = $_.id
                        Username   = $_.username
                        FirstName  = $_.firstname
                        LastName   = $_.lastname
                        Email      = $_.email
                        Account    = $_.account
                        DomainID   = $_.domainid
                        DomainName = $_.domain
                        State      = $_.state
                    }
                }
            } else {
                Write-Warning "Keine Benutzer gefunden."
            }
        } catch {
            Write-Error "Fehler beim Abrufen der Benutzer: $_"
        }
    }
}

<#
.SYNOPSIS
    Löscht einen CloudStack-Benutzer.
.DESCRIPTION
    Diese Funktion löscht einen Benutzer in CloudStack.
.PARAMETER UserID
    Die ID des zu löschenden Benutzers.
.EXAMPLE
    Remove-CloudStackUser -UserID "1234"
#>
function Remove-CloudStackUser {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$UserID  # Die ID des zu löschenden Benutzers
    )

    begin {
        # Überprüfe globale Variablen
        if (-not $Global:CloudStackBaseUrl -or -not $Global:CloudStackApiKey -or -not $Global:CloudStackSecretKey) {
            throw "Bitte zuerst Connect-CloudStack ausführen, um eine Verbindung zu CloudStack herzustellen."
        }
    }

    process {
        try {
            # Bestätigungsdialog
            if ($PSCmdlet.ShouldProcess("Benutzer mit ID '$UserID'", "Löschen")) {
                # API-Parameter definieren
                $Parameters = @{
                    "command"  = "deleteUser"
                    "id"       = $UserID
                    "response" = "json"
                }

                # Signierte URL erstellen
                $SignedUrl = Get-SignedUrl -Parameters $Parameters

                # Anfrage senden
                $Response = Invoke-RestMethod -Uri $SignedUrl -Method Get

                # Überprüfung der API-Antwort
                if ($Response.deleteuserresponse) {
                    Write-Host "Benutzer mit ID '$UserID' erfolgreich gelöscht." -ForegroundColor Green
                } else {
                    throw "Fehler beim Löschen des Benutzers: $($Response | ConvertTo-Json -Depth 10)"
                }
            }
        } catch {
            Write-Error "Fehler beim Löschen des Benutzers mit ID '$UserID': $_"
        }
    }
}


<#
.SYNOPSIS
    Erstellt einen neuen CloudStack-Benutzer.
.DESCRIPTION
    Diese Funktion erstellt einen neuen Benutzer in CloudStack.
.PARAMETER Username
    Der Benutzername des neuen Benutzers.
.PARAMETER Password
    Das Passwort des neuen Benutzers.
.PARAMETER FirstName
    Der Vorname des Benutzers.
.PARAMETER LastName
    Der Nachname des Benutzers.
.PARAMETER Email
    Die E-Mail-Adresse des neuen Benutzers.
.PARAMETER AccountName
    Der Name des bestehenden Accounts.
.PARAMETER DomainID
    Die ID der Domain, in der der Account liegt.
.EXAMPLE
    New-CloudStackUser -Username "user1" -Password "password" -FirstName "Max" -LastName "Mustermann" -Email "user1@test.de" -AccountName "Account1" -DomainID "1234"

#>
function New-CloudStackUser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Username,      # Benutzername des neuen Benutzers

        [Parameter(Mandatory = $true)]
        [string]$Password,      # Passwort des neuen Benutzers

        [Parameter(Mandatory = $true)]
        [string]$FirstName,     # Vorname des Benutzers

        [Parameter(Mandatory = $true)]
        [string]$LastName,      # Nachname des Benutzers

        [Parameter(Mandatory = $true)]
        [string]$Email,         # E-Mail-Adresse des Benutzers

        [Parameter(Mandatory = $true)]
        [string]$AccountName,   # Name des bestehenden Accounts

        [Parameter(Mandatory = $true)]
        [string]$DomainID       # DomainID, in der der Account liegt
    )

    begin {
        # Überprüfe globale Variablen
        if (-not $Global:CloudStackBaseUrl -or -not $Global:CloudStackApiKey -or -not $Global:CloudStackSecretKey) {
            throw "Bitte zuerst Connect-CloudStack ausführen, um eine Verbindung zu CloudStack herzustellen."
        }
    }

    process {
        try {
            # API-Parameter definieren
            $Parameters = @{
                "command"    = "createUser"
                "username"   = $Username
                "password"   = $Password
                "firstname"  = $FirstName
                "lastname"   = $LastName
                "email"      = $Email
                "account"    = $AccountName
                "domainid"   = $DomainID
                "response"   = "json"
            }

            # Signierte URL erstellen
            $SignedUrl = Get-SignedUrl -Parameters $Parameters

            # Anfrage senden
            $Response = Invoke-RestMethod -Uri $SignedUrl -Method Get

            # Überprüfung der API-Antwort
            if ($Response.createuserresponse) {
                Write-Host "Benutzer '$Username' wurde erfolgreich zum Account '$AccountName' hinzugefügt." -ForegroundColor Green
                return $Response.createuserresponse.user
            } else {
                throw "Fehler beim Hinzufügen des Benutzers: $($Response | ConvertTo-Json -Depth 10)"
            }
        } catch {
            Write-Error "Fehler beim Hinzufügen des Benutzers '$Username' zum Account '$AccountName': $_"
        }
    }
}


<#
.SYNOPSIS
Setzt das Limit für eine bestimmte Ressource (z. B. VMs, Speicher, Netzwerke) in CloudStack.

.DESCRIPTION
Dieses Cmdlet erlaubt es, das Limit für Ressourcen wie Benutzerinstanzen, öffentliche IP-Adressen, Volumes usw. 
für einen spezifischen Account, eine Domain oder ein Projekt zu konfigurieren.

.PARAMETER ResourceType
Der Typ der Ressource, deren Limit geändert werden soll. Die folgenden Werte sind verfügbar:

    ResourceType | Beschreibung
    -------------|----------------------------
    0            | Benutzerinstanzen (VMs)
    1            | Öffentliche IP-Adressen
    2            | Volumes
    3            | Snapshots
    4            | Templates
    5            | Projekte
    6            | Netzwerke
    7            | VPCs
    8            | CPU-Kerne
    9            | Arbeitsspeicher (RAM)
    10           | Primärer Speicher (GiB)
    11           | Sekundärer Speicher (GiB)

.PARAMETER MaxLimit
Der neue maximale Wert, der für die angegebene Ressource festgelegt werden soll.

.PARAMETER Account
(Optional) Der Account, für den das Limit geändert werden soll.

.PARAMETER DomainID
(Optional) Die Domain, für die das Limit geändert werden soll.

.PARAMETER ProjectID
(Optional) Das Projekt, für das das Limit geändert werden soll.

.EXAMPLE
Set-CloudStackResourceLimit -ResourceType 0 -MaxLimit 50

Setzt das Limit für Benutzerinstanzen (VMs) global auf 50.

.EXAMPLE
Set-CloudStackResourceLimit -ResourceType 1 -MaxLimit 30 -Account "TestAccount"

Setzt das Limit für öffentliche IPs auf 30 für den Account "TestAccount".

.EXAMPLE
Set-CloudStackResourceLimit -ResourceType 9 -MaxLimit 81920 -DomainID "5bf5927f-91dd-11ef-bd59-46e70d67c9bd"

Setzt das Limit für Arbeitsspeicher (RAM) auf 81.920 MiB in der angegebenen Domain.

.EXAMPLE
Set-CloudStackResourceLimit -ResourceType 10 -MaxLimit 500 -ProjectID "12345-abcde-67890-fghij"

Setzt das Limit für primären Speicher (GiB) auf 500 für das Projekt mit der angegebenen ID.

.NOTES
- Globale Variablen wie $CloudStackBaseUrl, $CloudStackApiKey und $CloudStackSecretKey müssen gesetzt sein.
- Das Cmdlet überprüft die Berechtigungen und erwartet, dass der API-Benutzer die entsprechenden Rechte besitzt.
- Bei Fehlern prüfe die CloudStack-Logs auf dem Server: /var/log/cloudstack/management/management-server.log.

#>
function Set-CloudStackResourceLimit {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int]$ResourceType,       # Die Art der Ressource (z. B. 0 für Instanzen, 1 für IPs usw.)

        [Parameter(Mandatory = $true)]
        [int]$MaxLimit,           # Der neue maximale Wert für die Ressource

        [Parameter(Mandatory = $false)]
        [string]$Account,         # Optional: Der Account, für den das Limit geändert wird

        [Parameter(Mandatory = $false)]
        [string]$DomainID,        # Optional: Die Domain, für die das Limit geändert wird

        [Parameter(Mandatory = $false)]
        [string]$ProjectID        # Optional: Das Projekt, für das das Limit geändert wird
    )

    begin {
        # Überprüfe globale Variablen
        if (-not $Global:CloudStackBaseUrl -or -not $Global:CloudStackApiKey -or -not $Global:CloudStackSecretKey) {
            throw "Bitte zuerst Connect-CloudStack ausführen, um eine Verbindung zu CloudStack herzustellen."
        }
    }

    process {
        try {
            # API-Parameter definieren
            $Parameters = @{
                "command"      = "updateResourceLimit"
                "resourcetype" = $ResourceType
                "max"          = $MaxLimit
                "response"     = "json"
            }

            if ($Account) {
                $Parameters["account"] = $Account
            }

            if ($DomainID) {
                $Parameters["domainid"] = $DomainID
            }

            if ($ProjectID) {
                $Parameters["projectid"] = $ProjectID
            }

            # Signierte URL erstellen
            $SignedUrl = Get-SignedUrl -Parameters $Parameters

            # Anfrage senden
            $Response = Invoke-RestMethod -Uri $SignedUrl -Method Get

            # Überprüfung der API-Antwort
            if ($Response.updateresourcelimitresponse) {
                Write-Host "Das Limit für Ressourcentyp '$ResourceType' wurde erfolgreich auf '$MaxLimit' gesetzt." -ForegroundColor Green
            } else {
                throw "Fehler beim Aktualisieren des Limits: $($Response | ConvertTo-Json -Depth 10)"
            }
        } catch {
            Write-Error "Fehler beim Setzen des Limits: $_"
        }
    }
}

<#
.SYNOPSIS
Erstellt einen API-Key und ein API-Secret für einen Benutzer in CloudStack.

.DESCRIPTION
Dieses Cmdlet generiert einen API-Schlüssel und ein API-Secret für einen angegebenen Benutzer anhand der User-ID.

.PARAMETER UserID
Die ID des Benutzers, für den der API-Schlüssel erstellt werden soll.

.EXAMPLE
New-CloudStackApiKey -UserID "b4c025cb-b64c-44fb-940f-fb6160b60a7d"

Erstellt API-Schlüssel für den Benutzer mit der angegebenen User-ID.

.NOTES
- Die CloudStack-API verlangt eine User-ID, um API-Keys zu registrieren.
- Falls der Benutzer bereits einen API-Key hat, wird dieser überschrieben.
#>
function New-CloudStackApiKey {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserID   # ID des Benutzers, für den der API-Key generiert werden soll
    )

    begin {
        # Überprüfe, ob die Verbindung zu CloudStack besteht
        if (-not $Global:CloudStackBaseUrl -or -not $Global:CloudStackApiKey -or -not $Global:CloudStackSecretKey) {
            throw "Bitte zuerst Connect-CloudStack ausführen, um eine Verbindung zu CloudStack herzustellen."
        }
    }

    process {
        try {
            # API-Parameter für die Erstellung des API-Keys
            $ApiParams = @{
                "command"  = "registerUserKeys"
                "response" = "json"
                "id"       = $UserID
            }

            # Signierte URL erstellen
            $ApiUrl = Get-SignedUrl -Parameters $ApiParams

            # API-Request senden
            $ApiResponse = Invoke-RestMethod -Uri $ApiUrl -Method Get

            # Überprüfung der Antwort
            if ($ApiResponse.registeruserkeysresponse.userkeys.apikey -and $ApiResponse.registeruserkeysresponse.userkeys.secretkey) {
                $ApiKey = $ApiResponse.registeruserkeysresponse.userkeys.apikey
                $SecretKey = $ApiResponse.registeruserkeysresponse.userkeys.secretkey
                Write-Host "API-Key erfolgreich erstellt für Benutzer '$UserID'" -ForegroundColor Green

                # Rückgabe der API-Daten als Objekt
                return [PSCustomObject]@{
                    UserID    = $UserID
                    ApiKey    = $ApiKey
                    SecretKey = $SecretKey
                }
            } else {
                throw "Fehler beim Erstellen des API-Keys. API-Antwort: $($ApiResponse | ConvertTo-Json -Depth 10)"
            }
        } catch {
            Write-Error "Fehler beim Erstellen des API-Keys für Benutzer mit ID '$UserID': $_"
        }
    }
}
