function Get-SignedUrl {
    param (
        [Parameter(Mandatory = $false)]
        [string]$BaseUrl, # Basis-URL der CloudStack API (optional)

        [Parameter(Mandatory = $false)]
        [string]$ApiKey, # API-Schlüssel (optional)

        [Parameter(Mandatory = $false)]
        [string]$SecretKey, # Geheimschlüssel (optional)

        [Parameter(Mandatory = $true)]
        [hashtable]$Parameters # API-Parameter
    )

    # Globale Variablen verwenden, falls keine Parameter übergeben wurden
    if (-not $BaseUrl) {
        if ($Global:CloudStackBaseUrl) {
            $BaseUrl = $Global:CloudStackBaseUrl
        }
        else {
            throw "Basis-URL nicht angegeben und keine globale Variable vorhanden."
        }
    }

    #Write-Host $BaseUrl

    if (-not $ApiKey) {
        if ($Global:CloudStackApiKey) {
            $ApiKey = $Global:CloudStackApiKey
        }
        else {
            throw "API-Schlüssel nicht angegeben und keine globale Variable vorhanden."
        }
    }

    if (-not $SecretKey) {
        if ($Global:CloudStackSecretKey) {
            $SecretKey = $Global:CloudStackSecretKey
        }
        else {
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
    }
    catch {
        Write-Error "Fehler beim Abfragen des Job-Status für Job-ID '$JobId': $_"
    }
}

