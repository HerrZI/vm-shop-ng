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
  name             = "LinuxKursNW" # Netzwerkname
  display_text     = "Layer 3 Netzwerk für Windwos Projekt" #DefaultIsolatedNetworkOfferingWithSourceNatService
  network_offering = "4e9bfcb1-d441-4316-b86f-fb6696fde80b"  #DefaultIsolatedNetworkOfferingWithSourceNatService
  zone             = "c94601a1-fbaf-4067-bc78-d1b9cacfbcbe"  #Multi Media Berufsbildende Schulen
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

resource "cloudstack_port_forward" "Debian13Instance" {
  ip_address_id = cloudstack_ipaddress.public_ip.id # Referenziert die öffentliche IP-Adresse
  forward {
    protocol          = "tcp"
    private_port      = 22                      # Port der VM
    public_port       = 22                      # Externer Port
    virtual_machine_id = cloudstack_instance.Debian.id # Ziel-VM
  }
}

resource "cloudstack_port_forward" "DevuanInstance" {
  ip_address_id = cloudstack_ipaddress.public_ip.id # Referenziert die öffentliche IP-Adresse
  forward {
    protocol          = "tcp"
    private_port      = 22                      # Port der VM
    public_port       = 23                      # Externer Port
    virtual_machine_id = cloudstack_instance.Devuan.id # Ziel-VM
  }
}

# Firewall von public ip öffnen für Ports 22 und 23 für TCP
resource "cloudstack_firewall" "allow_ssh" {
  ip_address_id = cloudstack_ipaddress.public_ip.id # Öffentliche IP-Adresse
  depends_on = [ cloudstack_port_forward.Debian13Instance, cloudstack_port_forward.DevuanInstance ]

  rule {
    protocol  = "tcp"
    cidr_list = ["0.0.0.0/0"] # Zugriff von überall erlauben
    ports     = ["22","23"]        # Port öffnen
  }
}

resource "cloudstack_instance" "Debian" {
  name             = "Debian"
  service_offering = "Big Instance"
  template         = "a42be8f9-674c-4468-872b-64f89b8f9721" #Debian13-mit-SSH
  network_id       = cloudstack_network.vlan_network.id
  zone             = "Multi Media Berufsbildende Schulen"
  ip_address       = "10.100.2.10"
  expunge          = true
  #start_vm         = false
  # Cloud-Init für Passwort, Gateway und DNS
  user_data = <<EOT
#cloud-config
datasource:
  None

chpasswd:
  list: |
    mmbbs:mmbbs
  expire: False
ssh_pwauth: True

runcmd:
  - hostname debian
EOT
}

resource "cloudstack_instance" "Devuan" {
  name             = "Devuan"
  service_offering = "Medium Instance"
  template         = "7c686e52-c42b-43a6-99c0-065131fcdc4a" #Devuan-mit-SSH
  network_id       = cloudstack_network.vlan_network.id
  zone             = "Multi Media Berufsbildende Schulen"
  ip_address       = "10.100.2.11"
  expunge          = true
  #start_vm         = false
  # Cloud-Init für Passwort, Gateway und DNS
  user_data = <<EOT
#cloud-config
datasource:
  None

chpasswd:
  list: |
    mmbbs:mmbbs
  expire: False
ssh_pwauth: True

runcmd:
  - hostname devuan
EOT
}

# Ausgaben definieren
output "Debian_id" {
  value = cloudstack_instance.Debian.id
}

output "Devuan_id" {
  value = cloudstack_instance.Devuan.id
}

output "network_id" {
  value = cloudstack_network.vlan_network.id
}

output "public_ip" {
  value       = cloudstack_ipaddress.public_ip.id
  description = "Die öffentliche IP-Adresse des Netzwerks"
}
