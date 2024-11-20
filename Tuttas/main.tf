variable "api_url" {}
variable "api_key" {}
variable "secret_key" {}


terraform {
  required_providers {
    cloudstack = {
      source  = "cloudstack/cloudstack"
      version = "0.4.0"
    }
  }
}

provider "cloudstack" {
  api_url    = var.api_url
  api_key    = var.api_key
  secret_key = var.secret_key
}

# Netzwerk definieren
#resource "cloudstack_network" "vlan_network" {
#  name             = "VLAN-Network"
#  display_text     = "VLAN Network for Linux VMs"
#  network_offering = "551f5a5f-d5b6-459e-96c4-661cf43c68dc"  # Beispiel-Network Offering
#  zone             = "a4848bf1-b2d1-4b39-97e3-72106df81f09" # Zone-ID
#  cidr             = "192.168.1.0/24"
#}

# Virtuelle Maschine 1 erstellen
resource "cloudstack_instance" "vm1" {
  name              = "linux-vm1"
  display_name      = "Linux VM 1"
  service_offering  = "Big Instance" # Ersetze mit dem passenden Service Offering
  template          = "5bfa057a-91dd-11ef-bd59-46e70d67c9bd" # Ersetze mit deiner Template-ID
  zone              = "a4848bf1-b2d1-4b39-97e3-72106df81f09" # Zone-ID
  #network_id        = cloudstack_network.vlan_network.id
  # expunge           = true # Automatisches Löschen bei Terraform Destroy
  root_password     = "SecurePassword123!" # Hier wird das Root-Passwort gesetzt
  # Root-Disk konfigurieren
  root_disk_size    = 20 # Größe der Root-Disk in GB
}

# Virtuelle Maschine 2 erstellen
resource "cloudstack_instance" "vm2" {
  name              = "linux-vm2"
  display_name      = "Linux VM 2"
  service_offering  = "Big Instance" # Ersetze mit dem passenden Service Offering
  template          = "5bfa057a-91dd-11ef-bd59-46e70d67c9bd" # Ersetze mit deiner Template-ID
  zone              = "a4848bf1-b2d1-4b39-97e3-72106df81f09" # Zone-ID
  #network_id        = cloudstack_network.vlan_network.id
  # expunge           = true # Automatisches Löschen bei Terraform Destroy
  root_password     = "SecurePassword123!" # Hier wird das Root-Passwort gesetzt
  # Root-Disk konfigurieren
  root_disk_size    = 20 # Größe der Root-Disk in GB
}

# Ausgaben definieren
#output "network_id" {
#  value = cloudstack_network.vlan_network.id
#}

output "vm1_id" {
  value = cloudstack_instance.vm1.id
}

output "vm2_id" {
  value = cloudstack_instance.vm2.id
}
