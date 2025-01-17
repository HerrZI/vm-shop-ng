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
$data = Import-Excel $pfad | select -Property Gruppe -Unique

$domainID = Read-Host "Bitte geben Sie die Domain-ID ein [z.B. 5b7e8018-d8bf-4e60-9f15-8d6083dbbfcb]: "
if ($domainID -eq "") {
    $domainID = "5b7e8018-d8bf-4e60-9f15-8d6083dbbfcb"
}

$createdAccounts = @{}
Get-CloudStackAccounts -DomainID $domainID | ForEach-Object { $createdAccounts[$_.Name] = $_}

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
