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
  name             = "FISI22Inw" # Netzwerkname
  display_text     = "Layer 3 Netzwerk für Windwos Projekt" #DefaultIsolatedNetworkOfferingWithSourceNatService
  network_offering = "12d4fc87-3718-40b0-9707-2b53b8555cda"  # Beispiel-Network Offering
  zone             = "a4848bf1-b2d1-4b39-97e3-72106df81f09" # Zone-ID MMBBS
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
    virtual_machine_id = cloudstack_instance.vm1.id # Ziel-VM
  }
}

resource "cloudstack_port_forward" "rdpBDC02" {
  ip_address_id = cloudstack_ipaddress.public_ip.id # Referenziert die öffentliche IP-Adresse
  forward {
    protocol          = "tcp"
    private_port      = 3389                      # Port der VM
    public_port       = 3002                      # Externer Port
    virtual_machine_id = cloudstack_instance.vm2.id # Ziel-VM
  }
}

resource "cloudstack_port_forward" "rdpRDC01" {
  ip_address_id = cloudstack_ipaddress.public_ip.id # Referenziert die öffentliche IP-Adresse
  forward {
    protocol          = "tcp"
    private_port      = 3389                      # Port der VM
    public_port       = 3003                      # Externer Port
    virtual_machine_id = cloudstack_instance.vm3.id # Ziel-VM
  }
}

resource "cloudstack_port_forward" "rdpHBDC01" {
  ip_address_id = cloudstack_ipaddress.public_ip.id # Referenziert die öffentliche IP-Adresse
  forward {
    protocol          = "tcp"
    private_port      = 3389                      # Port der VM
    public_port       = 3004                      # Externer Port
    virtual_machine_id = cloudstack_instance.vm4.id # Ziel-VM
  }
}

resource "cloudstack_port_forward" "rdpBPC01" {
  ip_address_id = cloudstack_ipaddress.public_ip.id # Referenziert die öffentliche IP-Adresse
  forward {
    protocol          = "tcp"
    private_port      = 3389                      # Port der VM
    public_port       = 3005                      # Externer Port
    virtual_machine_id = cloudstack_instance.vm5.id # Ziel-VM
  }
}

resource "cloudstack_port_forward" "rdpRPC01" {
  ip_address_id = cloudstack_ipaddress.public_ip.id # Referenziert die öffentliche IP-Adresse
  forward {
    protocol          = "tcp"
    private_port      = 3389                      # Port der VM
    public_port       = 3006                      # Externer Port
    virtual_machine_id = cloudstack_instance.vm6.id # Ziel-VM
  }
}

resource "cloudstack_port_forward" "rdpHBPC01" {
  ip_address_id = cloudstack_ipaddress.public_ip.id # Referenziert die öffentliche IP-Adresse
  forward {
    protocol          = "tcp"
    private_port      = 3389                      # Port der VM
    public_port       = 3007                      # Externer Port
    virtual_machine_id = cloudstack_instance.vm7.id # Ziel-VM
  }
}

# Firewall von public ip öffnen für Ports 80, 22 und 3389 für TCP
resource "cloudstack_firewall" "allow_rdp" {
  ip_address_id = cloudstack_ipaddress.public_ip.id # Öffentliche IP-Adresse
  depends_on = [ cloudstack_port_forward.rdpBDC01, cloudstack_port_forward.rdpBDC02, cloudstack_port_forward.rdpRDC01, cloudstack_port_forward.rdpHBDC01, cloudstack_port_forward.rdpBPC01, cloudstack_port_forward.rdpRPC01, cloudstack_port_forward.rdpHBPC01 ]

  rule {
    protocol  = "tcp"
    cidr_list = ["0.0.0.0/0"] # Zugriff von überall erlauben
    ports     = ["3389"]        # Port öffnen
  }
}


output "network_id" {
  value = cloudstack_network.vlan_network.id
}

output "public_ip" {
  value       = cloudstack_ipaddress.public_ip.id
  description = "Die öffentliche IP-Adresse des Netzwerks"
}
