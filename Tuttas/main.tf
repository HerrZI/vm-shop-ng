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
  name             = "NetworkTU2"
  display_text     = "VLAN Network for Linux VMs"
  network_offering = "12d4fc87-3718-40b0-9707-2b53b8555cda"  # Beispiel-Network Offering
  zone             = "a4848bf1-b2d1-4b39-97e3-72106df81f09" # Zone-ID
  cidr             = "10.1.1.0/24"
  #vlan             = "250"  # Beispiel: VLAN-ID 300
}


resource "cloudstack_egress_firewall" "default" {
  network_id = cloudstack_network.vlan_network.id

  rule {
    cidr_list = ["10.1.1.0/24"]
    protocol  = "all"
    #ports     = ["80", "1000-2000"]
  }
}

resource "cloudstack_ipaddress" "public_ip" {
  network_id = cloudstack_network.vlan_network.id
}

resource "cloudstack_port_forward" "nginx_http" {
  ip_address_id = cloudstack_ipaddress.public_ip.id # Referenziert die öffentliche IP-Adresse
  forward {
    protocol          = "tcp"
    private_port      = 80                      # Port der VM
    public_port       = 80                      # Externer Port
    virtual_machine_id = cloudstack_instance.vm2.id # Ziel-VM
  }
}
resource "cloudstack_port_forward" "ssh" {
  ip_address_id = cloudstack_ipaddress.public_ip.id # Referenziert die öffentliche IP-Adresse
  forward {
    protocol          = "tcp"
    private_port      = 22                      # Port der VM
    public_port       = 22                      # Externer Port
    virtual_machine_id = cloudstack_instance.vm2.id # Ziel-VM
  }

}
resource "cloudstack_port_forward" "rdp" {
  ip_address_id = cloudstack_ipaddress.public_ip.id # Referenziert die öffentliche IP-Adresse
  forward {
    protocol          = "tcp"
    private_port      = 3389                      # Port der VM
    public_port       = 3389                      # Externer Port
    virtual_machine_id = cloudstack_instance.vm3.id # Ziel-VM
  }
}


# Firewall von public ip öffnen für Ports 80, 22 und 3389 für TCP
resource "cloudstack_firewall" "allow_http" {
  ip_address_id = cloudstack_ipaddress.public_ip.id # Öffentliche IP-Adresse
  depends_on = [ cloudstack_port_forward.nginx_http, cloudstack_port_forward.ssh, cloudstack_port_forward.rdp ]

  rule {
    protocol  = "tcp"
    cidr_list = ["0.0.0.0/0"] # Zugriff von überall erlauben
    ports     = ["80","22","3389"]        # Port öffnen
  }
}



# Virtuelle Maschine 1 erstellen
resource "cloudstack_instance" "vm1" {
  name              = "linux-vm1"
  display_name      = "Linux VM 1"
  service_offering  = "Big Instance"
  template          = "f5295a59-8eb5-4c73-9768-cf67dcf3656b"
  zone              = "a4848bf1-b2d1-4b39-97e3-72106df81f09"
  network_id        = cloudstack_network.vlan_network.id
  root_disk_size    = 20
  keypair           = "tuttas"
  expunge           = true
  ip_address        = "10.1.1.100"

  # Cloud-Init für Passwort, Gateway und DNS
  user_data = <<EOT
#cloud-config
datasource:
  None

network:
  config: disabled

password: geheim
chpasswd:
  list: |
    ubuntu:geheim
  expire: False
ssh_pwauth: True

write_files:
  - path: /tmp/test-file.txt
    permissions: '0644'
    content: |
      Hello, this is a test file.
  - path: /etc/netplan/51-cloud-init.yaml
    permissions: '0644'
    content: |
      network:
        version: 2
        ethernets:
          ens3:
            optional: false
            dhcp4: false
            addresses:
              - 10.1.1.100/24
            nameservers:
              addresses:
                - 8.8.8.8
            routes:
              - to: default
                via: 10.1.1.1

bootcmd:
  - ip link set ens3 up

runcmd:
  - netplan generate
  - netplan apply
  - apt-get update -y
  - apt-get install -y lynx
EOT
}


resource "cloudstack_instance" "vm2" {
  name              = "linux-vm2"
  display_name      = "Linux VM 2"
  service_offering  = "Big Instance"
  template          = "f5295a59-8eb5-4c73-9768-cf67dcf3656b"
  zone              = "a4848bf1-b2d1-4b39-97e3-72106df81f09"
  network_id        = cloudstack_network.vlan_network.id
  root_disk_size    = 20
  keypair           = "tuttas"
  expunge           = true
  ip_address        = "10.1.1.101"

  # Cloud-init: Benutzername, Passwort, Netzwerk und DNS
  user_data = <<EOT
#cloud-config
datasource:
  None

network:
  config: disabled

password: geheim
chpasswd:
  list: |
    ubuntu:geheim
  expire: False

ssh_pwauth: True

write_files:
  - path: /etc/netplan/51-cloud-init.yaml
    permissions: '0644'
    content: |
      network:
        version: 2
        ethernets:
          ens3:
            optional: false
            dhcp4: false
            addresses:
              - 10.1.1.101/24
            nameservers:
              addresses:
                - 8.8.8.8
            routes:
              - to: default
                via: 10.1.1.1

bootcmd:
  - ip link set ens3 up

runcmd:
  - netplan generate
  - netplan apply
  - apt-get update -y
  - curl -fsSL https://get.docker.com | sudo bash
  - git clone https://gist.github.com/863959868cf293029454053053758266.git moodle
  - cd moodle
  - docker compose up -d

EOT
}

# Virtuelle Maschine 3 erstellen

resource "cloudstack_instance" "vm3" {
  name              = "windows-vm3"
  display_name      = "Windows VM 3"
  service_offering  = "Big Instance"
  template          =  "9b00c942-7ed5-4548-98fc-182615c23d1f"
  zone              = "a4848bf1-b2d1-4b39-97e3-72106df81f09"
  network_id        = cloudstack_network.vlan_network.id
  root_disk_size    = 20
  keypair           = "tuttas"
  expunge           = true
  ip_address        = "10.1.1.103"
# PowerShell-Skript für Cloudbase-Init mit #ps1-Header
  user_data = <<EOT
#cloud-config  
network:
  version: 1
  config:
    - type: physical
      name: "Ethernet"
      subnets:
        - type: static
          address: 10.1.1.103
          netmask: 255.255.255.0
          gateway: 10.1.1.1
          dns_nameservers:
            - 8.8.8.8
            - 8.8.4.4

#ps1
New-Item -Path 'C:\\HalloWelt.txt' -ItemType File -Force
Set-Content -Path 'C:\\HalloWelt.txt' -Value 'Hallo MMBBS4'

Start-Sleep -Seconds 10

# Netzwerkverbindung abrufen
$network = Get-NetConnectionProfile

# Netzwerkprofil auf "Privat" setzen
Set-NetConnectionProfile -Name $network.Name -NetworkCategory Private
EOT  
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
  value = cloudstack_network.vlan_network
}
output "public_ip" {
  value       = cloudstack_ipaddress.public_ip.ip_address
  description = "Die öffentliche IP-Adresse des Netzwerks"
}
