# Erstellen von Projekten und VMs in Cloudstack
## 0. Konfiguration
Es muss im Ordner LF10b eine Datei config.psd1 angelegt werden mit folgendem Inhalt:

``` bash
@{
    CSBaseUrl       = ""
    UserApiKey      = ""
    UserSecretKey   = ""
}
``` 
Die Variablen sind sinvoll zu füllen.

## 1. Projekte anlegen
In der Datei **LF10b_Klassen.psd1** sind im Array **FisiKlassen** die Klassennamen hinterlegt, für die Projekte erstellt werden. Momentan 1 Projekt pro Klasse.
In der Variablen **NamensZusatz** kann man einen Prefix für die Projektnamen vergeben ("", wenn kein Präfix gewünscht).

Rufe die Datei **LF10b_createProjects.ps1** auf, um die entsprechenden Projekte zu erzeugen.

## 2. VMs in den Projekten anlegen
Rufe **terraform init** und anschließend **terraform apply** auf, um die Maschinen B-PC01, HB-PC01, R-PC01 und B-DC01, B-DC02, HB-DC01, R-DC01 zu erzeugen.
Werden sie nicht mehr benötigt, können sie mit **terraform destroy** gelöscht werden.

## 3. Projekte löschen
Nach **terraform destroy** rufe die Datei **LF10b_deleteProjects.ps1** auf, um die entsprechenden Projekte zu löschen.
