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

# Lade die Projekte aus der von PorweShell erzeügten JSON-Datei 
locals {
  projects = jsondecode(file("projects.json"))
}

# 3. Mehrere Compute Instanzen erstellen und mit dem Netzwerk verbinden
variable "pc_instances" {
  default = ["B-PC01", "R-PC01", "HB-PC01"] # Hier kannst du weitere Instanznamen hinzufügen
}

variable "dc_instances" {
  default = ["B-DC01", "B-DC02", "HB-DC01", "R-DC01"] # Hier kannst du weitere Instanznamen hinzufügen
}

# 2. Netzwerk erstellen und dem Projekt zuordnen
resource "cloudstack_network" "project_networks" {  
  count             = length(local.projects.projects)
  name              = "NW-${local.projects.projects[count.index].name}-TF"
  display_text      = "NW-${local.projects.projects[count.index].name}-TF"
  cidr              = "10.1.0.0/24"
  network_offering  = "DefaultIsolatedNetworkOfferingWithSourceNatService" # Ersetze dies mit deinem spezifischen Network Offering
  zone              = "Multi Media Berufsbildende Schulen" # Zone, in der das Netzwerk erstellt wird
  project           = local.projects.projects[count.index].id
}

# 4. Compute Instance erstellen und mit dem Netzwerk verbinden
resource "cloudstack_instance" "PC" {
  count            = length(local.projects.projects) * length(var.pc_instances)
  name             = "${local.projects.projects[floor(count.index / length(var.pc_instances))].name}-${var.pc_instances[count.index % length(var.pc_instances)]}-TF"
  service_offering = "Big Instance"
  template         = "a06887cf-ebbd-44e5-8fd9-88795df535ab"
  network_id       = cloudstack_network.project_networks[floor(count.index / length(var.pc_instances))].id
  zone             = "Multi Media Berufsbildende Schulen"
  project          = local.projects.projects[floor(count.index / length(var.pc_instances))].id
  expunge          = true
}

resource "cloudstack_instance" "DC" { 
  count            = length(local.projects.projects) * length(var.dc_instances)
  name             = "${local.projects.projects[floor(count.index / length(var.dc_instances))].name}-${var.dc_instances[count.index % length(var.dc_instances)]}-TF"
  service_offering = "Big Instance"
  template         = "f355eae1-9af1-4ec5-94b5-f06c7e109782"
  network_id       = cloudstack_network.project_networks[floor(count.index / length(var.dc_instances))].id
  zone             = "Multi Media Berufsbildende Schulen"
  project          = local.projects.projects[floor(count.index / length(var.dc_instances))].id
  expunge          = true
}

# Ausgaben definieren
output "PC_Instances" {
  value = [for instance in cloudstack_instance.PC : instance.id]
}

output "DC_Instances" {  
  value = [for instance in cloudstack_instance.DC : instance.id]
}
