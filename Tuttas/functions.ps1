﻿function Get-SignedUrl {
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

    $Parameters["apikey"] = $ApiKey
    $Parameters["response"] = "json"

    # Sortiere die Parameter alphabetisch
    $SortedParams = $Parameters.GetEnumerator() | Sort-Object Name
    $QueryString = $SortedParams.ForEach({ "$($_.Name)=$($_.Value)" }) -join "&"

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

            Write-Host "Signierte URL: $SignedUrl" -ForegroundColor Yellow

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
function Get-CloudStackUsers {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$DomainId,  # Optional: Filter nach Domain-ID

        [Parameter(Mandatory = $false)]
        [string]$Account,   # Optional: Filter nach Account

        [Parameter(Mandatory = $false)]
        [switch]$ListAll    # Optional: Alle Benutzer anzeigen
    )

    begin {
        # Globale Variablen prüfen
        if (-not $Global:CloudStackBaseUrl -or -not $Global:CloudStackApiKey -or -not $Global:CloudStackSecretKey) {
            throw "Bitte zuerst Connect-CloudStack ausführen, um eine Verbindung zu CloudStack herzustellen."
        }
    }

    process {
        try {
            # API-Parameter für die Benutzerabfrage
            $Parameters = @{ "command" = "listUsers" }

            if ($DomainId) {
                $Parameters["domainid"] = $DomainId
            }
            if ($Account) {
                $Parameters["account"] = $Account
            }
            if ($ListAll) {
                $Parameters["listall"] = "true"
            }

            # Signierte URL erstellen
            $SignedUrl = Get-SignedUrl -Parameters $Parameters

            # Anfrage an die API senden
            $Response = Invoke-RestMethod -Uri $SignedUrl -Method Get

            # Überprüfung der Antwort
            if ($Response.listusersresponse.user) {
                $Response.listusersresponse.user | ForEach-Object {
                    [PSCustomObject]@{
                        ID           = $_.id
                        Username     = $_.username
                        FirstName    = $_.firstname
                        LastName     = $_.lastname
                        Email        = $_.email
                        Account      = $_.account
                        Domain       = $_.domain
                        State        = $_.state
                        Created      = $_.created
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

function Remove-CloudStackUser {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$UserId  # ID des Benutzers, der gelöscht werden soll
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
            if ($PSCmdlet.ShouldProcess("Benutzer mit ID '$UserId'", "Löschen")) {
                # API-Parameter für das Löschen des Benutzers
                $Parameters = @{
                    "command" = "deleteUser"
                    "id"      = $UserId
                }

                # Signierte URL erstellen
                $SignedUrl = Get-SignedUrl -Parameters $Parameters

                # Anfrage an die API senden
                $Response = Invoke-RestMethod -Uri $SignedUrl -Method Get

                # Überprüfung der Antwort
                if ($Response.deleteuserresponse) {
                    Write-Host "Benutzer mit ID '$UserId' wurde erfolgreich gelöscht." -ForegroundColor Green
                } else {
                    throw "Benutzer konnte nicht gelöscht werden. API-Antwort: $($Response | ConvertTo-Json -Depth 10)"
                }
            }
        } catch {
            Write-Error "Fehler beim Löschen des Benutzers '$UserId': $_"
        }
    }
}

function New-CloudStackUser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Username,

        [Parameter(Mandatory = $true)]
        [string]$Password,

        [Parameter(Mandatory = $true)]
        [string]$FirstName,

        [Parameter(Mandatory = $true)]
        [string]$LastName,

        [Parameter(Mandatory = $true)]
        [string]$Email,

        [Parameter(Mandatory = $true)]
        [string]$Account,

        [Parameter(Mandatory = $true)]
        [string]$DomainID
    )

    begin {
        # Globale Variablen prüfen
        if (-not $Global:CloudStackBaseUrl -or -not $Global:CloudStackApiKey -or -not $Global:CloudStackSecretKey) {
            throw "Bitte zuerst Connect-CloudStack ausführen, um eine Verbindung zu CloudStack herzustellen."
        }
    }

    process {
        try {
            # API-Parameter
            $Parameters = @{
                "command"    = "createUser"
                "username"   = $Username
                "password"   = $Password
                "firstname"  = $FirstName
                "lastname"   = $LastName
                "email"      = $Email
                "account"    = $Account
                "domainid"   = $DomainID
            }

            # Signierte URL erstellen
            $SignedUrl = Get-SignedUrl -Parameters $Parameters

            Write-Host "Signierte URL: $SignedUrl" -ForegroundColor Yellow
            $Headers = @{
    "Accept"       = "application/json"
    "Content-Type" = "application/x-www-form-urlencoded"
}
            # Anfrage mit Invoke-WebRequest senden
            $Response = Invoke-WebRequest -Uri $SignedUrl -Headers $Headers -Method Get


            # JSON-Antwort parsen
            $ParsedResponse = $Response.Content | ConvertFrom-Json

            if ($ParsedResponse.createuserresponse) {
                Write-Host "Benutzer '$Username' wurde erfolgreich erstellt." -ForegroundColor Green
                return $ParsedResponse.createuserresponse
            } else {
                throw "Benutzer konnte nicht erstellt werden. API-Antwort: $($Response.Content)"
            }
        } catch {
            Write-Error "Fehler beim Erstellen des Benutzers '$Username': $_"
        }
    }
}
