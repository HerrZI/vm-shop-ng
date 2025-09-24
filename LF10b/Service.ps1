function setSecret {
    param (
        [string]$Key,
        [string]$Value
    )

    # Pfad zur Datei
    $filePath = "secret.json"

    # Verschlüsselung des Wertes
    $secureValue = ConvertTo-SecureString $Value -AsPlainText -Force
    $encryptedValue = ConvertFrom-SecureString $secureValue

    # Laden der existierenden Daten
    if (Test-Path $filePath) {
        $json = Get-Content $filePath | ConvertFrom-Json
        $hashTable = @{}
        $json.PSObject.Properties | ForEach-Object { $hashTable[$_.Name] = $_.Value }
    } else {
        $hashTable = @{}
    }

    # Hinzufügen oder Aktualisieren des Schlüssels
    $hashTable[$Key] = $encryptedValue

    # Speichern der Daten in der Datei
    $hashTable | ConvertTo-Json | Set-Content $filePath
}

function getSecret {
    param (
        [string]$Key
    )

    # Pfad zur Datei
    $filePath = "secret.json"

    # Überprüfen, ob die Datei existiert
    if (Test-Path $filePath) {
        $json = Get-Content $filePath | ConvertFrom-Json
        $hashTable = @{}
        $json.PSObject.Properties | ForEach-Object { $hashTable[$_.Name] = $_.Value }

        # Überprüfen, ob der Key existiert
        if ($hashTable.ContainsKey($Key)) {
            $encryptedValue = $hashTable[$Key]
            $secureString = ConvertTo-SecureString $encryptedValue
            $plainTextValue = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString))
            return $plainTextValue
        }
    }

    return $null
}

if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    Install-Module -Name ImportExcel -Force -Scope CurrentUser
}
if (-not (Get-Module -ListAvailable -Name CSHelper)) {
    Install-Module -Name CSHelper -Force -Scope CurrentUser
}

if (-not $Global:CloudStackBaseUrl -or -not $Global:CloudStackApiKey -or -not $Global:CloudStackSecretKey) {
    
    $ApiKey = getSecret -Key "ApiKey"
    $Secret = getSecret -Key "Secret"

    if ($ApiKey -eq $null -or $Secret -eq $null) {
        $ApiKey = Read-Host "Bitte geben Sie den CloudStack API-Key ein"
        $Secret = Read-Host "Bitte geben Sie den CloudStack Secret-Key ein"
    }
    $url = "https://cloudstack.mm-bbs.de/client/api"
    Connect-CloudStack -BaseUrl $url -ApiKey $ApiKey -SecretKey $Secret        
    if (-not $Global:CloudStackBaseUrl -or -not $Global:CloudStackApiKey -or -not $Global:CloudStackSecretKey) {
        Write-Error "Fehler beim Verbinden mit CloudStack."
        exit
    }
    setSecret -Key "ApiKey" -Value $ApiKey
    setSecret -Key "Secret" -Value $Secret
}
else {
    setSecret -Key "ApiKey" -Value $Global:CloudStackApiKey
    setSecret -Key "Secret" -Value $Global:CloudStackSecretKey
}

# Abfrage des Pfades mit variable als Default-Wert
$defaultValue = getSecret -Key "DefaultPath"
if ($defaultValue -eq $null) {
    $defaultValue = "d:\Temp\vm-shop-ng\Tuttas\Wahl.xlsx"
}
$pfad = Read-Host "Bitte geben Sie den Pfad zur Excel-Datei ein [$defaultValue]"
if ([string]::IsNullOrWhiteSpace($pfad)) {
    $pfad = $defaultValue
}
if (-not (Test-Path $pfad)) {
    Write-Error "Datei '$pfad' existiert nicht."
    exit
} 
setSecret -Key "DefaultPath" -Value $pfad
$global:data = Import-Excel $pfad 

$defaultValue = getSecret -Key "DomainID"
if ($defaultValue -eq $null) {
    $defaultValue = "5b7e8018-d8bf-4e60-9f15-8d6083dbbfcb"
}
$domainID = Read-Host "Bitte geben Sie die Domain-ID ein [z.B. $defaultValue]"
if ([string]::IsNullOrWhiteSpace($domainID)) {
    $domainID = $defaultValue
}
setSecret -Key "DomainID" -Value $domainID
$Global:domainID = $domainID

