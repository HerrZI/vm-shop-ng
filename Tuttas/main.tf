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

resource "cloudstack_template" "template1" {
  name          = "TuttasTemplate"
  os_type      = "Other Linux (64-bit)"
  zone            = "a4848bf1-b2d1-4b39-97e3-72106df81f09"
  url           = "http://dl.openvm.eu/cloudstack/macchinina/x86_64/macchinina-kvm.qcow2.bz2"
  format        = "QCOW2"
  hypervisor    = "KVM"
  password_enabled = true
}

# Netzwerk definieren
resource "cloudstack_network" "vlan_network" {
  name             = "VLAN-Network"
  display_text     = "VLAN Network for Linux VMs"
  network_offering = "12d4fc87-3718-40b0-9707-2b53b8555cda"  # Beispiel-Network Offering
  zone             = "a4848bf1-b2d1-4b39-97e3-72106df81f09" # Zone-ID
  cidr             = "10.1.36.0/24"
  #vlan             = "500"  # Beispiel: VLAN-ID 300
}

# Virtuelle Maschine 1 erstellen
resource "cloudstack_instance" "vm1" {
  name              = "linux-vm1"
  display_name      = "Linux VM 1"
  service_offering  = "Big Instance" # Ersetze mit dem passenden Service Offering
  template         = cloudstack_template.template1.id
  #template = "5bfa057a-91dd-11ef-bd59-46e70d67c9bd"
  zone              = "a4848bf1-b2d1-4b39-97e3-72106df81f09" # Zone-ID
  network_id        = cloudstack_network.vlan_network.id  # Automatisch das ID des Netzwerks verwenden
  root_disk_size    = 20 # Größe der Root-Disk in GB
    # SSH-Key-Paar angeben
  keypair           = "tuttas"
  expunge = true
  ip_address        = "10.1.36.100"

}

# Virtuelle Maschine 2 erstellen
resource "cloudstack_instance" "vm2" {
  name              = "linux-vm2"
  display_name      = "Linux VM 2"
  service_offering  = "Big Instance" # Ersetze mit dem passenden Service Offering
  template         = cloudstack_template.template1.id
  #template = "5bfa057a-91dd-11ef-bd59-46e70d67c9bd"

  zone              = "a4848bf1-b2d1-4b39-97e3-72106df81f09" # Zone-ID
  network_id        = cloudstack_network.vlan_network.id  # Automatisch das ID des Netzwerks verwenden
  root_disk_size    = 20 # Größe der Root-Disk in GB
    # SSH-Key-Paar angeben
  keypair           = "tuttas"
  expunge = true
  ip_address        = "10.1.36.101"
}

# Ausgaben definieren
output "vm1_id" {
  value = cloudstack_instance.vm1.id
}

output "vm2_id" {
  value = cloudstack_instance.vm2.id
}

output "network_id" {
  value = cloudstack_network.vlan_network.id
}
