# Import private Funktionen
. $PSScriptRoot\Private\Helper.ps1

# Export Cmdlets
Export-ModuleMember -Function Connect-CloudStack, Add-CloudStackUser, Remove-CloudStackUser, List-CloudStackProjects, New-CloudStackProject, Remove-CloudStackProject

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

