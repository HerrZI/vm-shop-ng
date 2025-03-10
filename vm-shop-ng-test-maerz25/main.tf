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
  name             = "FISI22I" # Netzwerkname
  display_text     = "Layer 3 Netzwerk für Windwos Projekt" #DefaultIsolatedNetworkOfferingWithSourceNatService
  network_offering = "12d4fc87-3718-40b0-9707-2b53b8555cda"  # Beispiel-Network Offering
  zone             = "a4848bf1-b2d1-4b39-97e3-72106df81f09" # Zone-ID MMBBS
  cidr             = "10.100.2.0/24" # Beispiel für unterschiedliche Subnetze
}

resource "cloudstack_egress_firewall" "default" {
  network_id = cloudstack_network.vlan_network.id  # Verknüpfe mit dem Netzwerk aus der vorherigen Ressource

  rule {
    cidr_list = ["10.100.2.0/24"]  # CIDR-Adresse für jedes Netzwerk dynamisch
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


# Firewall von public ip öffnen für Ports 80, 22 und 3389 für TCP
resource "cloudstack_firewall" "allow_rdp" {
  ip_address_id = cloudstack_ipaddress.public_ip.id # Öffentliche IP-Adresse
  depends_on = [ cloudstack_port_forward.rdpBDC01, cloudstack_port_forward.rdpBDC02, cloudstack_port_forward.rdpRDC01, cloudstack_port_forward.rdpBPC01, cloudstack_port_forward.rdpRPC01 ]

  rule {
    protocol  = "tcp"
    cidr_list = ["0.0.0.0/0"] # Zugriff von überall erlauben
    ports     = ["3001", "3002", "3003", "3004", "3005", "3006", "3007"]        # Port öffnen 
  }
}

resource "cloudstack_instance" "B-PC01" {
  name             = "B-PC01"
  service_offering = "Big Instance"
  template         = "3f692b17-29b5-40d1-9815-e55f33f28a02"
  network_id       = cloudstack_network.vlan_network.id
  zone             = "Multi Media Berufsbildende Schulen"
  ip_address        = "10.100.2.10"
  expunge          = true
}

resource "cloudstack_instance" "R-PC01" {
  name             = "R-PC01"
  service_offering = "Big Instance"
  template         = "3f692b17-29b5-40d1-9815-e55f33f28a02"
  network_id       = cloudstack_network.vlan_network.id
  zone             = "Multi Media Berufsbildende Schulen"
  ip_address        = "10.100.2.11"
  expunge          = true
}


resource "cloudstack_instance" "B-DC01" { 
  name             = "B-DC01"
  service_offering = "Big Instance"
  template         = "2c8ac632-ff16-4edf-9e00-4a55811f2514"
  network_id       = cloudstack_network.vlan_network.id
  zone             = "Multi Media Berufsbildende Schulen"
  ip_address        = "10.100.2.13"
  expunge          = true
}

resource "cloudstack_instance" "B-DC02" { 
  name             = "B-DC02"
  service_offering = "Big Instance"
  template         = "2c8ac632-ff16-4edf-9e00-4a55811f2514"
  network_id       = cloudstack_network.vlan_network.id
  zone             = "Multi Media Berufsbildende Schulen"
  ip_address        = "10.100.2.14"
  expunge          = true
}

resource "cloudstack_instance" "R-DC01" { 
  name             = "R-DC01"
  service_offering = "Big Instance"
  template         = "2c8ac632-ff16-4edf-9e00-4a55811f2514"
  network_id       = cloudstack_network.vlan_network.id
  zone             = "Multi Media Berufsbildende Schulen"
  ip_address        = "10.100.2.15"
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

output "B-PC01_id" {
  value = cloudstack_instance.B-PC01.id
}

output "R-PC01_id" {
  value = cloudstack_instance.R-PC01.id
}

output "network_id" {
  value = cloudstack_network.vlan_network.id
}

output "public_ip" {
  value       = cloudstack_ipaddress.public_ip.id
  description = "Die öffentliche IP-Adresse des Netzwerks"
}
