# Importiere die Konfigurationsdatei mit BaseUrl, API Key und Secret Key
$config = Import-PowerShellDataFile -Path "config.psd1"

# Importiere die CloudStack Funktionen
. ../Tuttas/functions.ps1

#Importiere die anzulegenden Klassen (Projekte)
$Klassen = Import-PowerShellDataFile -Path "LF10b_Klassen.psd1"

# Variablen
$projectsFile = "projects.json"
$ProjectID_FISI_LF10B = "5b7e8018-d8bf-4e60-9f15-8d6083dbbfcb"


# Hauptteil des Skripts
#----------------------

# Mit Cloudstack verbinden
Write-Host "Verbinde mit CloudStack..." $config.CSBaseUrl
Connect-CloudStack -BaseUrl $config.CSBaseUrl -ApiKey $config.UserApiKey -SecretKey $config.UserSecretKey

# Bestätigung ausschalten
 $ConfirmPreference = "None"

# Projekte löschen
foreach ($Klasse in $Klassen.FisiKlassen) {
    $ProjektName = $Klasse + $Klassen.NamensZusatz
    Write-Host "Loesche Projekt $ProjektName..."
    $Projekt = Get-CloudStackProjects -DomainId $ProjectID_FISI_LF10B -Name $ProjektName
    $Projekt.Id
    #Remove-CloudStackProject -ID $Projekt.Id
    Write-Host "Projekt $ProjektName geloescht."
}

# Bestätigung einschalten
 $ConfirmPreference = "High"

# Inhalt der Logdatei leeren
Set-Content -Path $projectsFile -Value ""

# Skriptende