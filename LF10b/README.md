# Erstellen von Projekten und VMs in Cloudstack
## Konfiguration
Es muss im Ordner LF10b eine Datei config.psd1 angelegt werden mit folgendem Inhalt:

``` bash
@{
    CSBaseUrl       = ""
    UserApiKey      = ""
    UserSecretKey   = ""
}
``` 
Die Variablen sind sinvoll zu füllen.

## Projekte anlegen
In der Datei **LF10b_Klassen.psd1** sind im Array **FisiKlassen** die Klassennamen hinterlegt, für die Projekte erstellt werden. Momentan 1 Projekt pro Klasse.
In der Variablen **NamensZusatz** kann man einen Prefix für die Projektnamen vergeben ("", wenn kein Präfix gewünscht).

Rufe die Datei **LF10b_createProjects.ps1** auf, um die entsprechenden Projekte zu erzeugen.

## Projekte löschen
Rufe die Datei **LF10b_deleteProjects.ps1** auf, um die entsprechenden Projekte zu löschen.

# VMs in den Projekten anlegen
TODO
