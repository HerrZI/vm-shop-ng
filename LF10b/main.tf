variable "api_url" {}
variable "api_key" {}
variable "secret_key" {}


terraform {
  required_providers {
    cloudstack = {
      source  = "cloudstack/cloudstack"
      version = "0.5.0"
    }
  }
}

provider "cloudstack" {
  api_url    = var.api_url
  api_key    = var.api_key
  secret_key = var.secret_key
}

# Netzwerk definieren
resource "cloudstack_network" "vlan_network" {
  name             = "FISI-NW" # Netzwerkname
  display_text     = "Layer 3 Netzwerk für Windwos Projekt" 
  network_offering = "4e9bfcb1-d441-4316-b86f-fb6696fde80b"  #DefaultIsolatedNetworkOfferingWithSourceNatService
  zone             = "c94601a1-fbaf-4067-bc78-d1b9cacfbcbe"  #Multi Media Berufsbildende Schulen
  cidr             = "10.100.1.0/24" # Beispiel für unterschiedliche Subnetze
}

resource "cloudstack_egress_firewall" "default" {
  network_id = cloudstack_network.vlan_network.id  # Verknüpfe mit dem Netzwerk aus der vorherigen Ressource

  rule {
    cidr_list = ["10.100.1.0/24"]  # CIDR-Adresse für jedes Netzwerk dynamisch
    protocol  = "all"
  }
}

resource "cloudstack_ipaddress" "public_ip" {
  network_id = cloudstack_network.vlan_network.id  # Verknüpfe mit dem Netzwerk aus der vorherigen Ressource
}

resource "cloudstack_port_forward" "rdpBDC01" {
  ip_address_id = cloudstack_ipaddress.public_ip.id # Referenziert die öffentliche IP-Adresse
  forward {
    protocol          = "tcp"
    private_port      = 3389                      # Port der VM
    public_port       = 3001                      # Externer Port
    virtual_machine_id = cloudstack_instance.B-DC01.id # Ziel-VM
  }
}

resource "cloudstack_port_forward" "rdpBDC02" {
  ip_address_id = cloudstack_ipaddress.public_ip.id # Referenziert die öffentliche IP-Adresse
  forward {
    protocol          = "tcp"
    private_port      = 3389                      # Port der VM
    public_port       = 3002                      # Externer Port
    virtual_machine_id = cloudstack_instance.B-DC02.id # Ziel-VM
  }
}

resource "cloudstack_port_forward" "rdpRDC01" {
  ip_address_id = cloudstack_ipaddress.public_ip.id # Referenziert die öffentliche IP-Adresse
  forward {
    protocol          = "tcp"
    private_port      = 3389                      # Port der VM
    public_port       = 3003                      # Externer Port
    virtual_machine_id = cloudstack_instance.R-DC01.id # Ziel-VM
  }
}

resource "cloudstack_port_forward" "rdpHBDC01" {
  ip_address_id = cloudstack_ipaddress.public_ip.id # Referenziert die öffentliche IP-Adresse
  forward {
    protocol          = "tcp"
    private_port      = 3389                      # Port der VM
    public_port       = 3004                      # Externer Port
    virtual_machine_id = cloudstack_instance.HB-DC01.id # Ziel-VM
  }
}

resource "cloudstack_port_forward" "rdpBPC01" {
  ip_address_id = cloudstack_ipaddress.public_ip.id # Referenziert die öffentliche IP-Adresse
  forward {
    protocol          = "tcp"
    private_port      = 3389                      # Port der VM
    public_port       = 3005                      # Externer Port
    virtual_machine_id = cloudstack_instance.B-PC01.id # Ziel-VM
  }
}

resource "cloudstack_port_forward" "rdpRPC01" {
  ip_address_id = cloudstack_ipaddress.public_ip.id # Referenziert die öffentliche IP-Adresse
  forward {
    protocol          = "tcp"
    private_port      = 3389                      # Port der VM
    public_port       = 3006                      # Externer Port
    virtual_machine_id = cloudstack_instance.R-PC01.id # Ziel-VM
  }
}

resource "cloudstack_port_forward" "rdpHBPC01" {
  ip_address_id = cloudstack_ipaddress.public_ip.id # Referenziert die öffentliche IP-Adresse
  forward {
    protocol          = "tcp"
    private_port      = 3389                      # Port der VM
    public_port       = 3007                      # Externer Port
    virtual_machine_id = cloudstack_instance.HB-PC01.id # Ziel-VM
  }
}

# Firewall von public ip öffnen für Ports 80, 22 und 3389 für TCP
resource "cloudstack_firewall" "allow_rdp" {
  ip_address_id = cloudstack_ipaddress.public_ip.id # Öffentliche IP-Adresse
  depends_on = [ cloudstack_port_forward.rdpBDC01, cloudstack_port_forward.rdpBDC02, cloudstack_port_forward.rdpRDC01, cloudstack_port_forward.rdpHBDC01, cloudstack_port_forward.rdpBPC01, cloudstack_port_forward.rdpRPC01, cloudstack_port_forward.rdpHBPC01 ]

  rule {
    protocol  = "tcp"
    cidr_list = ["0.0.0.0/0"] # Zugriff von überall erlauben
    ports     = ["3001", "3002", "3003", "3004", "3005", "3006", "3007"]        # Port öffnen 
  }
}

resource "cloudstack_instance" "B-PC01" {
  name             = "B-PC01"
  service_offering = "Windows Server 2022 (LF10b)"
  template         = "26e42b2f-3c6f-43dd-bf6b-2e83765b9872" # Windows-11-Template (LF10b)
  network_id       = cloudstack_network.vlan_network.id
  zone             = "Multi Media Berufsbildende Schulen"
  ip_address        = "10.100.1.10"
  expunge          = true
}

resource "cloudstack_instance" "R-PC01" {
  name             = "R-PC01"
  service_offering = "Windows Server 2022 (LF10b)"
  template         = "26e42b2f-3c6f-43dd-bf6b-2e83765b9872" # Windows-11-Template (LF10b)
  network_id       = cloudstack_network.vlan_network.id
  zone             = "Multi Media Berufsbildende Schulen"
  ip_address        = "10.100.1.11"
  expunge          = true
}

resource "cloudstack_instance" "HB-PC01" {
  name             = "HB-PC01"
  service_offering = "Windows Server 2022 (LF10b)"
  template         = "26e42b2f-3c6f-43dd-bf6b-2e83765b9872" # Windows-11-Template (LF10b)
  network_id       = cloudstack_network.vlan_network.id
  zone             = "Multi Media Berufsbildende Schulen"
  ip_address        = "10.100.1.12"
  expunge          = true
}

resource "cloudstack_instance" "B-DC01" { 
  name             = "B-DC01"
  service_offering = "Windows Server 2022 (LF10b)"
  template         = "bcea4c53-ac5c-4fe6-83ea-54065801ba63" # Windows-Server-2022-Template (LF10b)
  network_id       = cloudstack_network.vlan_network.id
  zone             = "Multi Media Berufsbildende Schulen"
  ip_address        = "10.100.1.13"
  expunge          = true
}

resource "cloudstack_instance" "B-DC02" { 
  name             = "B-DC02"
  service_offering = "Windows Server 2022 (LF10b)"
  template         = "bcea4c53-ac5c-4fe6-83ea-54065801ba63" # Windows-Server-2022-Template (LF10b)
  network_id       = cloudstack_network.vlan_network.id
  zone             = "Multi Media Berufsbildende Schulen"
  ip_address        = "10.100.1.14"
  expunge          = true
}

resource "cloudstack_instance" "R-DC01" { 
  name             = "R-DC01"
  service_offering = "Windows Server 2022 (LF10b)"
  template         = "bcea4c53-ac5c-4fe6-83ea-54065801ba63" # Windows-Server-2022-Template (LF10b)
  network_id       = cloudstack_network.vlan_network.id
  zone             = "Multi Media Berufsbildende Schulen"
  ip_address        = "10.100.1.15"
  expunge          = true
}

resource "cloudstack_instance" "HB-DC01" { 
  name             = "HB-DC01"
  service_offering = "Windows Server 2022 (LF10b)"
  template         = "bcea4c53-ac5c-4fe6-83ea-54065801ba63" # Windows-Server-2022-Template (LF10b)
  network_id       = cloudstack_network.vlan_network.id
  zone             = "Multi Media Berufsbildende Schulen"
  ip_address        = "10.100.1.16"
  expunge          = true
}

# Ausgaben definieren
output "B-DC01_id" {
  value = cloudstack_instance.B-DC01.id
}

output "B-DC02_id" {
  value = cloudstack_instance.B-DC02.id
}

output "R-DC01_id" {
  value = cloudstack_instance.R-DC01.id
}

output "HB-DC01_id" {
  value = cloudstack_instance.HB-DC01.id
}

output "B-PC01_id" {
  value = cloudstack_instance.B-PC01.id
}

output "R-PC01_id" {
  value = cloudstack_instance.R-PC01.id
}

output "HB-PC01_id" {
  value = cloudstack_instance.HB-PC01.id
}

output "network_id" {
  value = cloudstack_network.vlan_network.id
}

output "public_ip" {
  value       = cloudstack_ipaddress.public_ip.id
  description = "Die öffentliche IP-Adresse des Netzwerks"
}
