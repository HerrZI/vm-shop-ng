terraform {
 required_providers {
    cloudstack = {
      source  = "cloudstack/cloudstack"
      version = "0.4.0"
    }
  }
}

provider "cloudstack" {
  api_url    = "https://deine-cloudstack-url.de/client/api"
  api_key    = "dein-api-key"
  secret_key = "dein-secret-key"
}

resource "cloudstack_project" "example_project" {
  name         = "Terraform-Projekt"
  display_text = "Projekt für Terraform Deployment"
}


# Netzwerk definieren: VLAN mit dem IP-Bereich 192.168.1.0/24
resource "cloudstack_network" "vlan_network" {
  name          = "VLAN-Network"
  display_text  = "VLAN Network for Windows Servers and Clients"
  network_offering = "DefaultIsolatedNetworkOfferingWithSourceNatService"  # Beispiel-Network Offering
  zone          = "your-zone-name" # Name der Zone
  cidr          = "192.168.1.0/24"
}

# Variable für das Windows-Template definieren
variable "windows_template" {
  description = "Template ID for Windows OS"
  default     = "your-windows-template-id"  # Hier die Template-ID des Windows-Basisimages einfügen
}

# Funktion zum Erstellen einer Instanz aus einem Template
resource "cloudstack_instance" "windows_server" {
  count         = 4
  name          = "Windows-Server-${count.index + 1}"
  service_offering = "Small" # Beispiel-Service Offering für die Server-Instanzen
  template      = var.windows_template
  network_id    = cloudstack_network.vlan_network.id
  zone          = "your-zone-name" # Name der Zone
}

resource "cloudstack_instance" "windows_client" {
  count         = 3
  name          = "Windows-Client-${count.index + 1}"
  service_offering = "Small" # Beispiel-Service Offering für die Client-Instanzen
  template      = var.windows_template
  network_id    = cloudstack_network.vlan_network.id
  zone          = "your-zone-name" # Name der Zone
}

# Ausgabe der IP-Adressen der Server
output "windows_server_ips" {
  value = [for server in cloudstack_instance.windows_server : server.ip_address]
}

# Ausgabe der IP-Adressen der Clients
output "windows_client_ips" {
  value = [for client in cloudstack_instance.windows_client : client.ip_address]
}
