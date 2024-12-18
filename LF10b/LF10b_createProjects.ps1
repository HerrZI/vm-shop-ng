# Importiere die Konfigurationsdatei mit BaseUrl, API Key und Secret Key
$config = Import-PowerShellDataFile -Path "config.psd1"

#Importiere die anzulegenden Klassen (Projekte)
$Klassen = Import-PowerShellDataFile -Path "LF10b_Klassen.psd1"

# Importiere die CloudStack Funktionen
. ../Tuttas/functions.ps1

# Variablen
$logFile = "logfile.txt"


# Hauptteil des Skripts
#----------------------

# Mit Cloudstack verbinden
Write-Host "Verbinde mit CloudStack..." $config.CSBaseUrl
Connect-CloudStack -BaseUrl $config.CSBaseUrl -ApiKey $config.UserApiKey -SecretKey $config.UserSecretKey

# Projekte erstellen
foreach ($Klasse in $Klassen.FisiKlassen) {
    $ProjektName = $Klasse + $Klassen.NamensZusatz
    Write-Host "Erstelle Projekt $ProjektName..."
    $Projekt = New-CloudStackProject -Name $ProjektName    
    Write-Host "Projekt $ProjektName erstellt."
    $logMessage = $ProjektName + ", " + $Projekt.Id
    Add-Content -Path $logFile -Value $logMessage
}

# Skriptende