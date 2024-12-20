# Importiere die Konfigurationsdatei mit BaseUrl, API Key und Secret Key
$config = Import-PowerShellDataFile -Path "config.psd1"

# Importiere die CloudStack Funktionen
. ../Tuttas/functions.ps1

# Variablen
$projectsFile = "projects.json"

#Importiere die zu löschenden Klassen (Projekte)
$jsonProjects = Get-Content -Path $projectsFile -Raw

# In ein PowerShell-Objekt umwandeln
$Klassen = $jsonProjects | ConvertFrom-Json

# Hauptteil des Skripts
#----------------------
# Mit Cloudstack verbinden
Write-Host "Verbinde mit CloudStack..." $config.CSBaseUrl
Connect-CloudStack -BaseUrl $config.CSBaseUrl -ApiKey $config.UserApiKey -SecretKey $config.UserSecretKey

# Bestätigung ausschalten
# $ConfirmPreference = "None"

# Projekte löschen
foreach ($project in $Klassen.projects) {
    $ProjektName = $project.name
    $ProjektID = $project.id
    Write-Host "Loesche Projekt $ProjektName mit der ID $ProjektID..."              
    Remove-CloudStackProject -ID $ProjektID
    Write-Host "Projekt $ProjektName geloescht."
}

# Bestätigung einschalten
# $ConfirmPreference = "High"

# Inhalt der Projects Datei leeren
# Set-Content -Path $projectsFile -Value ""

# Skriptende