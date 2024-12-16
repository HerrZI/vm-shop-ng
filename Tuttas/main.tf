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

resource "cloudstack_template" "template1" {
  name          = "TuttasTemplate"
  os_type      = "Ubuntu 18.04 LTS"
  zone            = "a4848bf1-b2d1-4b39-97e3-72106df81f09"
  url           = "http://dl.openvm.eu/cloudstack/ubuntu/x86_64/ubuntu-18.04-kvm.qcow2.bz2"
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
  cidr             = "10.1.1.0/24"
  vlan             = "250"  # Beispiel: VLAN-ID 300
}


resource "cloudstack_egress_firewall" "default" {
  network_id = cloudstack_network.vlan_network.id

  rule {
    cidr_list = ["10.1.1.0/24"]
    protocol  = "all"
    #ports     = ["80", "1000-2000"]
  }
}

# Virtuelle Maschine 1 erstellen
resource "cloudstack_instance" "vm1" {
  name              = "linux-vm1"
  display_name      = "Linux VM 1"
  service_offering  = "Big Instance"
  template          = cloudstack_template.template1.id
  zone              = "a4848bf1-b2d1-4b39-97e3-72106df81f09"
  network_id        = cloudstack_network.vlan_network.id
  root_disk_size    = 20
  keypair           = "tuttas"
  expunge           = true
  ip_address        = "10.1.1.100"

  # Cloud-Init für Passwort, Gateway und DNS
  user_data = base64encode(<<EOT
#cloud-config
datasource:
  None

password: geheim
chpasswd:
  list: |
    ubuntu:geheim
  expire: False
ssh_pwauth: True

write_files:
  - path: /etc/netplan/50-cloud-init.yaml
    permissions: '0644'
    content: |
      network:
        version: 2
        ethernets:
          eth0:
            addresses:
              - 10.1.1.100/24
            nameservers:
              addresses:
                - 8.8.8.8
            routes:
              - to: default
                via: 10.1.1.1
            match:
              macaddress: 02:01:01:03:00:03
            set-name: eth0

runcmd:
  - netplan generate
  - netplan apply
  - apt-get update
  - apt-get install -y lynx
EOT
  )
}


resource "cloudstack_instance" "vm2" {
  name              = "linux-vm2"
  display_name      = "Linux VM 2"
  service_offering  = "Big Instance"
  template          = cloudstack_template.template1.id
  zone              = "a4848bf1-b2d1-4b39-97e3-72106df81f09"
  network_id        = cloudstack_network.vlan_network.id
  root_disk_size    = 20
  keypair           = "tuttas"
  expunge           = true
  ip_address        = "10.1.1.101"

  # Cloud-init: Benutzername, Passwort, Netzwerk und DNS
  user_data = base64encode(<<EOT
#cloud-config
datasource:
  None

password: geheim
chpasswd:
  list: |
    ubuntu:geheim
  expire: False
ssh_pwauth: True

write_files:
  - path: /etc/netplan/50-cloud-init.yaml
    permissions: '0644'
    content: |
      network:
        version: 2
        ethernets:
          eth0:
            addresses:
              - 10.1.1.101/24
            nameservers:
              addresses:
                - 8.8.8.8
            routes:
              - to: default
                via: 10.1.1.1
            match:
              macaddress: 02:01:01:03:00:03
            set-name: eth0

runcmd:
  - netplan generate
  - netplan apply
  - apt-get update
  - apt-get install -y nginx
  - systemctl enable nginx
  - systemctl start nginx

EOT
  )
}

# Virtuelle Maschine 3 erstellen
resource "cloudstack_instance" "vm3" {
  name              = "windows-vm3"
  display_name      = "Windows VM 3"
  service_offering  = "Big Instance"
  template          =  "a06887cf-ebbd-44e5-8fd9-88795df535ab"
  zone              = "a4848bf1-b2d1-4b39-97e3-72106df81f09"
  network_id        = cloudstack_network.vlan_network.id
  root_disk_size    = 20
  keypair           = "tuttas"
  expunge           = true
  ip_address        = "10.1.1.102"

}

# Ausgaben definieren
output "vm1_id" {
  value = cloudstack_instance.vm1.id
}

output "vm2_id" {
  value = cloudstack_instance.vm2.id
}

output "vm3_id" {
  value = cloudstack_instance.vm3.id
}

output "network_id" {
  value = cloudstack_network.vlan_network.id
}
