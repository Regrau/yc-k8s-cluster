terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}


provider "yandex" {
  zone = "ru-central1-a"
}

resource "yandex_resourcemanager_folder" "k8s-folder" {
  name = "k8s-folder"
}

resource "yandex_vpc_network" "k8s_vpc" {
  name      = "K8S VPC"
  folder_id = yandex_resourcemanager_folder.k8s-folder.id
}

resource "yandex_vpc_subnet" "test_subnet" {
  v4_cidr_blocks = ["10.1.0.0/24"]
  folder_id      = yandex_resourcemanager_folder.k8s-folder.id
  network_id     = yandex_vpc_network.k8s_vpc.id
}

resource "yandex_iam_service_account" "k8s-test-sa" {
  name        = "k8s-test-sa"
  folder_id   = yandex_resourcemanager_folder.k8s-folder.id
  description = "Service Account for testing purposes"
}

resource "yandex_resourcemanager_folder_iam_member" "editor" {
  # Service account to be assigned "editor" role.
  folder_id = yandex_resourcemanager_folder.k8s-folder.id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.k8s-test-sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "images-puller" {
  folder_id = yandex_resourcemanager_folder.k8s-folder.id

  role   = "container-registry.images.puller"
  member = "serviceAccount:${yandex_iam_service_account.k8s-test-sa.id}"
}

resource "yandex_kubernetes_cluster" "test-cluster" {
  folder_id = yandex_resourcemanager_folder.k8s-folder.id

  network_id = yandex_vpc_network.k8s_vpc.id
  master {
    zonal {
      zone      = yandex_vpc_subnet.test_subnet.zone
      subnet_id = yandex_vpc_subnet.test_subnet.id
    }
    public_ip = true
  }
  service_account_id      = yandex_iam_service_account.k8s-test-sa.id
  node_service_account_id = yandex_iam_service_account.k8s-test-sa.id
  depends_on = [
    yandex_resourcemanager_folder_iam_member.editor,
    yandex_resourcemanager_folder_iam_member.images-puller
  ]
}

resource "yandex_kubernetes_node_group" "workers" {
  cluster_id = yandex_kubernetes_cluster.test-cluster.id
  name       = "workers"
  instance_template {
    platform_id = "standard-v2"

    network_interface {
      nat        = true
      subnet_ids = ["${yandex_vpc_subnet.test_subnet.id}"]
    }

    resources {
      memory = 2
      cores  = 2
    }

    boot_disk {
      type = "network-hdd"
      size = 64
    }

    scheduling_policy {
      preemptible = false
    }

    container_runtime {
      type = "containerd"
    }
  }
  scale_policy {
    fixed_scale {
      size = 1
    }
  }
}


output "cluster-config" {
  value = <<COMMAND
    # Command to get the k8s config
    yc managed-kubernetes cluster get-credentials --id ${yandex_kubernetes_cluster.test-cluster.id} --external --profile default
  COMMAND
}
