# Importiere die Konfigurationsdatei
$config = Import-PowerShellDataFile -Path "config.psd1"

# Importiere die Funktionen
. ../Tuttas/functions.ps1

# Variablen
$FisiKlassen = @("FISI24A", "FISI24B", "FISI24C", "FISI24D", "FISI24E", "FISI24F", "FISI24G", "FISI24H", "FISI24I")
$NamensZusatz = "_ZI_PS_Test"
$logFile = "logfile.txt"


# Hauptteil des Skripts
#----------------------

# Mit Cloudstack verbinden
Write-Host "Verbinde mit CloudStack..." $config.CSBaseUrl
Connect-CloudStack -BaseUrl $config.CSBaseUrl -ApiKey $config.UserApiKey -SecretKey $config.UserSecretKey

# Bestätigung ausschalten
$ConfirmPreference = "None"

# Projekte löschen
foreach ($Klasse in $FisiKlassen) {
    $ProjektName = "$Klasse$NamensZusatz"
    Write-Host "Loesche Projekt $ProjektName..."
    $Projekt = Get-CloudStackProjects -Name $ProjektName
    $Projekt.Id
    Remove-CloudStackProject -ProjectId $Projekt.Id
    Write-Host "Projekt $ProjektName geloescht."
}

# Bestätigung einschalten
$ConfirmPreference = "High"

# Inhalt der Logdatei leeren
Set-Content -Path $logFile -Value ""

# Skriptende