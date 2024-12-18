# Importiere die Konfigurationsdatei mit BaseUrl, API Key und Secret Key
$config = Import-PowerShellDataFile -Path "config.psd1"

#Importiere die anzulegenden Klassen (Projekte)
$Klassen = Import-PowerShellDataFile -Path "LF10b_Klassen.psd1"

# Importiere die CloudStack Funktionen
. ../Tuttas/functions.ps1

# Variablen
$projectsFile = "projects.json"
$ProjectID_FISI_LF10B = "5b7e8018-d8bf-4e60-9f15-8d6083dbbfcb"


# Hauptteil des Skripts
#----------------------

# Mit Cloudstack verbinden
Write-Host "Verbinde mit CloudStack..." $config.CSBaseUrl
Connect-CloudStack -BaseUrl $config.CSBaseUrl -ApiKey $config.UserApiKey -SecretKey $config.UserSecretKey

# Inhalt der projects Datei für Terraform initialisieren
Set-Content -Path $projectsFile -Value "{"
Add-Content -Path $projectsFile -Value "  `"projects`": ["


# Projekte erstellen
foreach ($Klasse in $Klassen.FisiKlassen) {
    $ProjektName = $Klasse + $Klassen.NamensZusatz
    Write-Host "Erstelle Projekt $ProjektName..."
    $Projekt = New-CloudStackProject -Name $ProjektName -DomainId $ProjectID_FISI_LF10B
    Write-Host "Projekt $ProjektName erstellt."
    $logMessage = "    { `"name`" : `"" + $ProjektName + "`", `"id`" : `"" + $Projekt.Id + "`" },"
    Add-Content -Path $projectsFile -Value $logMessage
}

# Das letzte Komma entfernen
$content = Get-Content -Path $projectsFile -Raw
$newContent = $content.Substring(0, $content.Length - 3)
Set-Content -Path $projectsFile -Value $newContent

# Inhalt der Logdatei schließen
Add-Content -Path $projectsFile -Value "  ]"
Add-Content -Path $projectsFile -Value "}"

# Skriptende