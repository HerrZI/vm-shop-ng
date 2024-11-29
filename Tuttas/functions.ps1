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
.EXAMPLE
    New-CloudStackProject -Name "Projekt1" 
#>
function New-CloudStackProject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Name,         # Name des Projekts

        [Parameter(Mandatory = $false)]
        [string]$DisplayText,  # Optional: Beschreibung des Projekts

        [Parameter(Mandatory = $false)]
        [string]$Account       # Optional: Account, dem das Projekt zugewiesen werden soll
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
                "name" = $Name
            }
            if ($DisplayText) {
                $Parameters["displaytext"] = $DisplayText
            }
            if ($Account) {
                $Parameters["account"] = $Account
            }

            # Signierte URL erstellen
            $SignedUrl = Get-SignedUrl -Parameters $Parameters

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
                } else {
                    throw "Fehler bei der Projekterstellung. Job-Status: $($JobResult.jobstatus)"
                }
            } else {
                throw "Keine Job-ID erhalten. API-Antwort: $($Response | ConvertTo-Json -Depth 10)"
            }
        } catch {
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
.EXAMPLE
    List-CloudStackProjects

#>
function List-CloudStackProjects {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$DomainId,   # Optional: Filter nach Domain-ID

        [Parameter(Mandatory = $false)]
        [string]$Account     # Optional: Filter nach Account
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

            # Signierte URL erstellen
            $SignedUrl = Get-SignedUrl -Parameters $Parameters

            # Anfrage an die API senden
            $Response = Invoke-RestMethod -Uri $SignedUrl -Method Get

            # Überprüfung der Antwort
            if ($Response.listprojectsresponse.project) {
                $Projects = $Response.listprojectsresponse.project
                # Ausgabe aller Projekte als PowerShell-Objekte
                $Projects | ForEach-Object {
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
.PARAMETER ProjectId
    Die ID des zu löschenden Projekts.
.EXAMPLE
    Remove-CloudStackProject -ProjectId "1234"

#>
function Remove-CloudStackProject {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$ProjectId   # ID des zu löschenden Projekts
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
            if ($PSCmdlet.ShouldProcess("Projekt mit ID '$ProjectId'", "Löschen")) {
                # API-Parameter für das Löschen eines Projekts
                $Parameters = @{
                    "command" = "deleteProject"
                    "id"      = $ProjectId
                }

                # Signierte URL erstellen
                $SignedUrl = Get-SignedUrl -Parameters $Parameters

                # Anfrage an die API senden
                $Response = Invoke-RestMethod -Uri $SignedUrl -Method Get

                # Überprüfung der Antwort
                if ($Response.deleteprojectresponse.jobid) {
                    $JobId = $Response.deleteprojectresponse.jobid
                    Write-Host "Löschen von Projekt '$ProjectId' gestartet. Warte auf Abschluss des Jobs ($JobId)..." -ForegroundColor Yellow

                    # Warte auf Job-Ergebnis
                    $JobResult = Wait-CloudStackJob -JobId $JobId

                    # Überprüfe das Ergebnis
                    if ($JobResult.jobstatus -eq 1) {
                        Write-Host "Projekt '$ProjectId' erfolgreich gelöscht." -ForegroundColor Green
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
    Add-CloudStackUser -ProjectId "1234" -Username "user1"
#>
function Add-CloudStackUser {
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
    Remove-CloudStackUser -ProjectId "1234" -Username "user1"
#>
function Remove-CloudStackUser {
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

