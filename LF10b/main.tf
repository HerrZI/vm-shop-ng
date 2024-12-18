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

#variable "projects" {
#  type = list(object({
#    name = string
#    id   = string
#  }))
#}

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
  for_each         = { for p in projects : p.name => p }
  name             = "NW_${each.key}_TF"
  display_text     = "NW_${each.key}_TF"
  cidr             = "10.1.${index(projects, each.value)}.0/24"
  network_offering = "DefaultIsolatedNetworkOfferingWithSourceNatService"
  zone             = "Multi Media Berufsbildende Schulen"
  project          = each.value.id
}

# 4. PC-Instanzen für alle Projekte erstellen und mit den Netzwerken verbinden
resource "cloudstack_instance" "PC" {
  count = length(projects) * length(pc_instances)
  name             = "${projects[count.index / length(pc_instances)].name}-${pc_instances[count.index % length(pc_instances)]}"
  service_offering = "Big Instance"
  template         = "a06887cf-ebbd-44e5-8fd9-88795df535ab"
  network_id       = cloudstack_network.project_networks[projects[count.index / length(pc_instances)].name].id
  zone             = "Multi Media Berufsbildende Schulen"
  project          = projects[count.index / length(pc_instances)].id
  expunge          = true
}

# 5. DC-Instanzen für alle Projekte erstellen und mit den Netzwerken verbinden
resource "cloudstack_instance" "DC" {
  count            = length(projects) * length(dc_instances)
  name             = "${projects[count.index / length(var.dc_instances)].name}-${dc_instances[count.index % length(dc_instances)]}"
  service_offering = "Big Instance"
  template         = "f355eae1-9af1-4ec5-94b5-f06c7e109782"
  network_id       = cloudstack_network.project_networks[projects[count.index / length(dc_instances)].name].id
  zone             = "Multi Media Berufsbildende Schulen"
  project          = projects[count.index / length(dc_instances)].id
  expunge          = true
}

# Ausgaben definieren
output "pc_instance_ids" {
  value = { for k, v in cloudstack_instance.PC : k => [for inst in v : inst.id] }
}

output "dc_instance_ids" {
  value = { for k, v in cloudstack_instance.DC : k => [for inst in v : inst.id] }
}