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
  name              = "NW-${local.projects.projects[0].name}-TF"
  display_text      = "NW-${local.projects.projects[0].name}-TF"
  cidr              = "10.1.0.0/24"
  network_offering  = "DefaultIsolatedNetworkOfferingWithSourceNatService" # Ersetze dies mit deinem spezifischen Network Offering
  zone              = "Multi Media Berufsbildende Schulen" # Zone, in der das Netzwerk erstellt wird
  project           = local.projects.projects[0].id
}

# 4. Compute Instance erstellen und mit dem Netzwerk verbinden
resource "cloudstack_instance" "PC" {  
  name             = "${local.projects.projects[0].name}-${var.pc_instances[0]}-TF"
  service_offering = "Big Instance"
  template         = "a06887cf-ebbd-44e5-8fd9-88795df535ab"
  network_id       = cloudstack_network.project_networks.id
  zone             = "Multi Media Berufsbildende Schulen"
  project          = local.projects.projects[0].id
  expunge          = true
}

resource "cloudstack_instance" "DC" {  
  name             = "${local.projects.projects[0].name}-${var.dc_instances[0]}-TF"
  service_offering = "Big Instance"
  template         = "f355eae1-9af1-4ec5-94b5-f06c7e109782"
  network_id       = cloudstack_network.project_networks.id
  zone             = "Multi Media Berufsbildende Schulen"
  project          = local.projects.projects[0].id
  expunge          = true
}

# Ausgaben definieren
output "FISI24X_Team1_PC_Instances" {
  value = cloudstack_instance.PC.id
}

output "FISI24X_Team1_DC_Instances" {  
  value = cloudstack_instance.DC.id 
}
