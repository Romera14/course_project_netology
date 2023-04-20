terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  token = "${var.do_token}"
#  cloud_id  = var.cloud_id
  folder_id = "${var.do_folder_id}"
  zone      = "ru-central1-a"
}

resource "yandex_iam_service_account" "test" {
  name        = "test"
  folder_id = "b1g817nmob937losobc1"
  description = "service account to manage IG"
}

resource "yandex_resourcemanager_folder_iam_binding" "editor" {
  folder_id = "b1g817nmob937losobc1"
  role      = "editor"
  members   = [
    "serviceAccount:${yandex_iam_service_account.test.id}",
  ]
}

resource "yandex_compute_instance_group" "ig-1" {
  name               = "fixed-ig-with-balancer"
  folder_id          = "b1g817nmob937losobc1"
  service_account_id = "${yandex_iam_service_account.test.id}"
  instance_template {
    platform_id = "standard-v3"
    resources {
      memory = 2
      cores  = 2
    }

    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = "fd8m8s42796gm6v7sf8e"
      }
    }

    network_interface {
      network_id = "${yandex_vpc_network.network-1.id}"
      subnet_ids = ["${yandex_vpc_subnet.subnet-1.id}"]
      nat = true
    }

    metadata = {
      ssh-keys = "${var.user_ssh_key}"
      user-data = "${file("/home/paromov/course_project_netology/metadata.yaml")}"
    }
  }

  scale_policy {
    fixed_scale {
      size = 2
    }
  }

  allocation_policy {
    zones = ["ru-central1-a"]
  }

  deploy_policy {
    max_unavailable = 1
    max_expansion   = 0
  }

  load_balancer {
    target_group_name        = "target-group"
    target_group_description = "load balancer target group"
  }
}

resource "yandex_vpc_network" "network-1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "ru-central1-a"
  network_id     = "${yandex_vpc_network.network-1.id}"
  v4_cidr_blocks = ["192.168.10.0/24"]
}

resource "yandex_lb_network_load_balancer" "load_balancer" {
  name = "load-balancer"
  listener {
    name = "my-listener"
    port = 80
  }
  attached_target_group {
    target_group_id = yandex_compute_instance_group.ig-1.load_balancer[0].target_group_id
    healthcheck {
      name = "http"
        http_options {
          port = 80
          path = "/"
        }
    }
  }
}