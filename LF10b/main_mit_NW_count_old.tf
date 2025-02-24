variable "api_url" {}
variable "api_key" {}
variable "secret_key" {}
variable "network_count" {
  default = 2
}

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
  count            = var.network_count  # Anzahl der Netzwerke (z. B. 7 Netzwerke)
  name             = "FISI22Inw${count.index + 1}" # Netzwerkname mit Index (Network1, Network2, ...)
  display_text     = "Layer 3 Netzwerk für Windwos Projekt" #DefaultIsolatedNetworkOfferingWithSourceNatService
  network_offering = "12d4fc87-3718-40b0-9707-2b53b8555cda"  # Beispiel-Network Offering
  zone             = "a4848bf1-b2d1-4b39-97e3-72106df81f09" # Zone-ID MMBBS
  cidr             = "10.100.${count.index + 1}.0/24" # Beispiel für unterschiedliche Subnetze (10.100.1.0/24, 10.100.2.0/24, ...)
}

resource "cloudstack_egress_firewall" "default" {
  count      = var.network_count  # Anzahl der Netzwerke (z. B. 7 Netzwerke)
  network_id = cloudstack_network.vlan_network[count.index].id  # Verknüpfe mit dem Netzwerk aus der vorherigen Ressource

  rule {
    cidr_list = ["10.100.${count.index + 1}.0/24"]  # CIDR-Adresse für jedes Netzwerk dynamisch
    protocol  = "all"
  }
}

resource "cloudstack_ipaddress" "public_ip" {
  count      = var.network_count  # Anzahl der IP-Adressen, z. B. 7
  network_id = cloudstack_network.vlan_network[count.index].id  # Verknüpfe mit dem Netzwerk aus der vorherigen Ressource
}

#resource "cloudstack_port_forward" "rdp" {
#  count      = var.network_count  # Anzahl der Netzwerke (z. B. 7 Netzwerke)
#  ip_address_id = cloudstack_ipaddress.public_ip[count.index].id # Referenziert die öffentliche IP-Adresse
#  forward {
#    protocol          = "tcp"
#    private_port      = 3389                      # Port der VM
#    public_port       = 3389                      # Externer Port
#    virtual_machine_id = cloudstack_instance.vm2.id # Ziel-VM
#  }
#}


output "network_id" {
  value = [for i in range(var.network_count) : cloudstack_network.vlan_network[i].id]
}

output "public_ip" {
  value       = [for i in range(var.network_count) : cloudstack_ipaddress.public_ip[i].id]
  description = "Die öffentliche IP-Adresse des Netzwerks"
}
