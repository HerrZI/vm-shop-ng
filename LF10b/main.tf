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

#resource "cloudstack_project" "FISI24X_Team1_Project" {
#  name        = "FISI24X_Team1"
#  display_text = "FISI24X_Team1"
#}

# 2. Netzwerk erstellen und dem Projekt zuordnen
resource "cloudstack_network" "FISI24X_Team1_Network" {
  name              = "NW_FISI24X_Team1_TF"
  display_text      = "NW_FISI24X_Team1_TF"
  cidr              = "10.1.1.0/24"
  network_offering  = "DefaultIsolatedNetworkOfferingWithSourceNatService" # Ersetze dies mit deinem spezifischen Network Offering
  zone              = "Multi Media Berufsbildende Schulen" # Zone, in der das Netzwerk erstellt wird
  project           = "46a73fd5-a767-4244-a2bd-6253e655609d"
#  project           = cloudstack_project.FISI24X_Team1_Project.id
}

# 3. Compute Instance erstellen und mit dem Netzwerk verbinden
resource "cloudstack_instance" "B-PC01" {
  name           = "FISI24X-Team1-B-PC01-TF"
  service_offering = "Big Instance"  # Ersetze dies mit deinem spezifischen Service Offering
  template        = "56b661ee-c4bb-4a10-9df4-e6830b1c5d69"  # Ersetze dies mit dem Namen/ID des Images
  network_id      = cloudstack_network.FISI24X_Team1_Network.id
  zone            = "Multi Media Berufsbildende Schulen"
  project         = "46a73fd5-a767-4244-a2bd-6253e655609d"
#  project         = "FISI24X_Team1"
}

# Ausgaben definieren
output "FISI24X_Team1_B-PC01" {
  value = cloudstack_instance.B-PC01.id
}