terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.151.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "yandex" {
  service_account_key_file = "key.json"
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = "ru-central1-a"
}

# -------------------
# VPC
# -------------------
resource "yandex_vpc_network" "main" {
  name = "web-network"
}

# Публичная подсеть
resource "yandex_vpc_subnet" "public" {
  name           = "public-subnet"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["192.168.0.0/24"]
}

# Приватные подсети
resource "yandex_vpc_subnet" "private_a" {
  name           = "private-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["192.168.10.0/24"]
  route_table_id = yandex_vpc_route_table.private.id
}

resource "yandex_vpc_subnet" "private_b" {
  name           = "private-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["192.168.20.0/24"]
  route_table_id = yandex_vpc_route_table.private.id
}

# -------------------
# NAT Gateway
# -------------------
resource "yandex_vpc_gateway" "nat" {
  name      = "nat-gateway"
  folder_id = var.yc_folder_id
  shared_egress_gateway {}
}

# -------------------
# Route Table
# -------------------
resource "yandex_vpc_route_table" "private" {
  name       = "private-rt"
  network_id = yandex_vpc_network.main.id
  folder_id  = var.yc_folder_id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat.id
  }
}

# -------------------
# Security Groups
# -------------------

# Bastion SG
resource "yandex_vpc_security_group" "bastion" {
  name        = "bastion-sg"
  network_id  = yandex_vpc_network.main.id

  ingress {
    description    = "SSH"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Ping"
    protocol       = "ICMP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Zabbix server port"
    protocol       = "TCP"
    port           = 10050
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    description    = "Any outgoing traffic"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}


# Zabbix SG
resource "yandex_vpc_security_group" "monitoring" {
  name       = "monitoring-sg"
  network_id = yandex_vpc_network.main.id

  ingress {
    description    = "HTTP"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "HTTPS"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description       = "SSH from bastion"
    protocol          = "TCP"
    port              = 22
    security_group_id = yandex_vpc_security_group.bastion.id
  }
  
  ingress {
    description    = "Zabbix server port"
    protocol       = "TCP"
    port           = 10050
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Any outgoing traffic"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Web SG
resource "yandex_vpc_security_group" "web" {
  name       = "web-sg"
  network_id = yandex_vpc_network.main.id

  ingress {
    description    = "HTTP"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description       = "SSH from bastion"
    protocol          = "TCP"
    port              = 22
    security_group_id = yandex_vpc_security_group.bastion.id
  }

  ingress {
    description       = "Zabbix agent"
    protocol          = "TCP"
    port              = 10050
    security_group_id = yandex_vpc_security_group.monitoring.id
  }

  egress {
    description    = "Any outgoing traffic"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Kibana SG
resource "yandex_vpc_security_group" "kibana" {
  name       = "kibana-sg"
  network_id = yandex_vpc_network.main.id

  ingress {
    description    = "HTTP"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "HTTPS"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Kibana"
    protocol       = "TCP"
    port           = 5601
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description       = "SSH from bastion"
    protocol          = "TCP"
    port              = 22
    security_group_id = yandex_vpc_security_group.bastion.id
  }

  ingress {
    description       = "Zabbix"
    protocol          = "TCP"
    port              = 10050
    security_group_id = yandex_vpc_security_group.monitoring.id
  }

  egress {
    description    = "Any outgoing traffic"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Elasticsearch SG
resource "yandex_vpc_security_group" "elasticsearch" {
  name       = "elasticsearch-sg"
  network_id = yandex_vpc_network.main.id

  ingress {
    description       = "Elasticsearch HTTP from Kibana"
    protocol          = "TCP"
    port              = 9200
    security_group_id = yandex_vpc_security_group.kibana.id
  }

  ingress {
    description    = "Elasticsearch transport port"
    protocol       = "TCP"
    port           = 9300
    v4_cidr_blocks = ["192.168.0.0/16"]
  }
  
  ingress {
    description       = "Elasticsearch HTTP from web servers"
    protocol          = "TCP"
    port              = 9200
    security_group_id = yandex_vpc_security_group.web.id
  }


  ingress {
    description       = "SSH from bastion"
    protocol          = "TCP"
    port              = 22
    security_group_id = yandex_vpc_security_group.bastion.id
  }

  ingress {
    description       = "Zabbix agent from Zabbix server"
    protocol          = "TCP"
    port              = 10050
    security_group_id = yandex_vpc_security_group.monitoring.id
  }

  egress {
    description    = "Any outgoing traffic"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# -------------------
# Ubuntu Image
# -------------------
data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2404-lts"
}

# -------------------
# Compute Instances
# -------------------
locals {
  vm_resources = {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }
  disk_size = 20
}

# Bastion
resource "yandex_compute_instance" "bastion" {
  name        = "bastion"
  hostname    = "bastion"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = local.vm_resources.cores
    memory        = local.vm_resources.memory
    core_fraction = local.vm_resources.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.bastion.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

# Web servers
resource "yandex_compute_instance" "s1" {
  name        = "s1"
  hostname    = "s1"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = local.vm_resources.cores
    memory        = local.vm_resources.memory
    core_fraction = local.vm_resources.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = local.disk_size
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_a.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.web.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_compute_instance" "s2" {
  name        = "s2"
  hostname    = "s2"
  platform_id = "standard-v3"
  zone        = "ru-central1-b"

  resources {
    cores         = local.vm_resources.cores
    memory        = local.vm_resources.memory
    core_fraction = local.vm_resources.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = local.disk_size
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_b.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.web.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

# Zabbix server
resource "yandex_compute_instance" "zabbix" {
  name        = "zabbix"
  hostname    = "zabbix"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = local.vm_resources.cores
    memory        = local.vm_resources.memory
    core_fraction = local.vm_resources.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = local.disk_size
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.monitoring.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

# Elasticsearch
resource "yandex_compute_instance" "elastic" {
  name        = "elastic"
  hostname    = "elastic"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = local.vm_resources.cores
    memory        = local.vm_resources.memory
    core_fraction = local.vm_resources.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = local.disk_size
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_a.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.elasticsearch.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

# Kibana
resource "yandex_compute_instance" "kibana" {
  name        = "kibana"
  hostname    = "kibana"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = local.vm_resources.cores
    memory        = local.vm_resources.memory
    core_fraction = local.vm_resources.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = local.disk_size
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.kibana.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

# Application Load Balancer
resource "yandex_alb_target_group" "web_tg" {
  name = "web-target-group"

  target {
    subnet_id  = yandex_vpc_subnet.private_a.id
    ip_address = yandex_compute_instance.s1.network_interface.0.ip_address
  }

  target {
    subnet_id  = yandex_vpc_subnet.private_b.id
    ip_address = yandex_compute_instance.s2.network_interface.0.ip_address
  }
}

resource "yandex_alb_backend_group" "web_bg" {
  name = "web-backend-group"

  http_backend {
    name             = "web-backend"
    port             = 80
    target_group_ids = [yandex_alb_target_group.web_tg.id]
    
    healthcheck {
      timeout             = "3s"
      interval            = "10s"
      healthy_threshold   = 2
      unhealthy_threshold = 2
      http_healthcheck {
        path = "/"
      }
    }
  }
}

resource "yandex_alb_http_router" "web_router" {
  name = "web-router"
}

resource "yandex_alb_virtual_host" "web_vhost" {
  name           = "web-virtual-host"
  http_router_id = yandex_alb_http_router.web_router.id

  route {
    name = "web-route"
    http_route {
      http_route_action {
        backend_group_id = yandex_alb_backend_group.web_bg.id
      }
    }
  }
}

resource "yandex_alb_load_balancer" "web_alb" {
  name       = "web-alb"
  network_id = yandex_vpc_network.main.id
  allocation_policy {
    location {
      zone_id   = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.public.id
    }
  }

  listener {
    name = "http-listener"
    endpoint {
      address {
        external_ipv4_address {}
      }
      ports = [80]
    }
    http {
      handler {
        http_router_id = yandex_alb_http_router.web_router.id
      }
    }
  }
}

#snap
resource "yandex_compute_snapshot_schedule" "snapshot" {
  name        = "snapshot"
  description = "Snapshots"

  schedule_policy {
    expression = "0 1 * * *"
  }

  retention_period = "168h"

  snapshot_spec {
    description = "retention-snapshot"
  }

  disk_ids = [
    yandex_compute_instance.s1.boot_disk[0].disk_id,
    yandex_compute_instance.s2.boot_disk[0].disk_id,
    yandex_compute_instance.bastion.boot_disk[0].disk_id,
    yandex_compute_instance.zabbix.boot_disk[0].disk_id,
    yandex_compute_instance.elastic.boot_disk[0].disk_id,
    yandex_compute_instance.kibana.boot_disk[0].disk_id,
  ]

  depends_on = [
    yandex_compute_instance.s1,
    yandex_compute_instance.s2,
    yandex_compute_instance.bastion,
    yandex_compute_instance.zabbix,
    yandex_compute_instance.elastic,
    yandex_compute_instance.kibana
  ]
}


# -------------------
# Генерация Ansible inventory
# -------------------
resource "local_file" "ansible_inventory" {
  filename = "/mnt/c/sys-diplom/cloud-terraform/ansible/inventory.ini"
  content  = <<EOT
[bastion]
bastion ansible_host=${yandex_compute_instance.bastion.network_interface.0.nat_ip_address} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa

[web]
s1.ru-central1.internal ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ProxyJump=ubuntu@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}'
s2.ru-central1.internal ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ProxyJump=ubuntu@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}'

[zabbix-server]
zabbix.ru-central1.internal ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ProxyJump=ubuntu@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}'

[kibana]
kibana.ru-central1.internal ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ProxyJump=ubuntu@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}'

[elasticsearch]
elastic.ru-central1.internal ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ProxyJump=ubuntu@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}'
EOT
}
# -------------------
# Генерация zabbix_agent2_conf
# -------------------
resource "local_file" "zabbix_agent2_conf" {
  filename = "/mnt/c/sys-diplom/cloud-terraform/ansible/zabbix_agent2.conf.j2"
  content  = <<EOT
PidFile=/var/run/zabbix/zabbix_agent2.pid
LogFile=/var/log/zabbix/zabbix_agent2.log
LogFileSize=0
Server=${yandex_compute_instance.zabbix.network_interface.0.ip_address},${yandex_compute_instance.zabbix.network_interface.0.nat_ip_address}
ListenPort=10050
ListenIP=0.0.0.0
Hostname={{ ansible_hostname }}
Include=/etc/zabbix/zabbix_agent2.d/*.conf
PluginSocket=/run/zabbix/agent.plugin.sock
ControlSocket=/run/zabbix/agent.sock
Include=/etc/zabbix/zabbix_agent2.d/plugins.d/*.conf
EOT
}
