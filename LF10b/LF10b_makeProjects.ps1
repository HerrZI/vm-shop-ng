# Importiere die Konfigurationsdatei
$config = Import-PowerShellDataFile -Path "config.psd1"

# Importiere die Funktionen
. ../Tuttas/functions.ps1

# Variablen
$FisiKlassen = @("FISI24A", "FISI24B", "FISI24C", "FISI24D", "FISI24E", "FISI24F", "FISI24G", "FISI24H", "FISI24I")
$NamensZusatz = "_ZI_PS_Test"



# Hauptteil des Skripts
#----------------------

# Mit Cloudstack verbinden
Write-Host "Verbinde mit CloudStack..." $config.CSBaseUrl
Connect-CloudStack -BaseUrl $config.CSBaseUrl -ApiKey $config.UserApiKey -SecretKey $config.UserSecretKey

# Projekte erstellen
foreach ($Klasse in $FisiKlassen) {
    $ProjektName = "$Klasse$NamensZusatz"
    Write-Host "Erstelle Projekt $ProjektName..."
    $Projekt = New-CloudStackProject -Name $ProjektName    
    Write-Host "Projekt $ProjektName erstellt."    


# Wartezeit von 5 Sekunden
Start-Sleep -Seconds 5

# Projekte löschen
foreach ($Klasse in $FisiKlassen) {
    $ProjektName = "$Klasse$NamensZusatz"
    Write-Host "Lösche Projekt $ProjektName..."
    $Projekt = Get-CloudStackProjects -Name $ProjektName
    $Projekt.Id
    Remove-CloudStackProject -ProjectId $Projekt.Id
    Write-Host "Projekt $ProjektName geloescht."
}

# Skriptende