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
    description    = "SSH from anywhere"
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
    description    = "HTTP from anywhere"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "HTTPS from anywhere"
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
    description    = "Zabbix server port for agents"
    protocol       = "TCP"
    port           = 10051
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

# Web SG
resource "yandex_vpc_security_group" "web" {
  name       = "web-sg"
  network_id = yandex_vpc_network.main.id

  ingress {
    description    = "HTTP from anywhere"
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

# Kibana SG
resource "yandex_vpc_security_group" "kibana" {
  name       = "kibana-sg"
  network_id = yandex_vpc_network.main.id

  ingress {
    description    = "HTTP from anywhere"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "HTTPS from anywhere"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Kibana default port"
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
    memory        = 4
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

  scheduling_policy { preemptible = true }
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

  scheduling_policy { preemptible = true }
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

# -------------------
# Application Load Balancer
# -------------------
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
