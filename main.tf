resource "google_compute_network" "test-1" {
  name                    = var.name
  auto_create_subnetworks = false


}
resource "google_compute_subnetwork" "test1-1" {
  name          = "${var.name}-subnet"
  region        = var.location
  ip_cidr_range = "10.0.0.0/24"
  network       = google_compute_network.test-1.name

}

resource "google_container_cluster" "cluster" {
  name                     = "${var.name}-cluster"
  location                 = var.location
  initial_node_count       = 1
  network                  = google_compute_network.test-1.name     #VPC
  subnetwork               = google_compute_subnetwork.test1-1.name #subnet
  remove_default_node_pool = true
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = "10.11.0.0/28"
  }
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "10.10.0.0/21"
    services_ipv4_cidr_block = "10.9.0.0/21"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "10.0.0.7/32"
      display_name = "net1"
    }

  }
}



resource "google_service_account" "service_account" {
  account_id   = "service-account"
  display_name = "service-account-name"

}

resource "google_container_node_pool" "nodepool" {
  cluster    = google_container_cluster.cluster.name
  name       = "${var.name}-nodepool"
  node_count = 1
  location   = var.location

  node_config {
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring"]
    service_account = google_service_account.service_account.email
    preemptible     = true
    machine_type    = "e2-medium"
    labels = {
      env = "dev"
    }
  }

}

#creating a jump host . this will aloow jump host to access gke cluster 

resource "google_compute_address" "internal_ip" {
  project      = var.project
  address_type = "INTERNAL"
  region       = var.location
  subnetwork   = "${var.name}-subnet"
  name         = "${var.name}-my-ip"
  address      = "10.0.0.7"
  description  = "an internal ip address for jump host "
}
resource "google_compute_instance" "default" {
  project      = var.project
  zone         = "us-central1-c"
  name         = "${var.name}-jump-host"
  machine_type = var.machine_type

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"

    }
  }
  network_interface {
    network    = "test-1"
    subnetwork = "${var.name}-subnet"
    network_ip = google_compute_address.internal_ip.address
  }

}
## creating firewall to access the jumphost via IAP(identity aware proxy)

resource "google_compute_firewall" "rules" {
  project = var.project
  name    = "${var.name}-allow-ssh"
  network = "test-1"
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["36.235.240.0/20"]
}
#create IAP ssh permissions for the instance 
resource "google_project_iam_member" "permissions" {
  project = var.project
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:terraform-demo@cts07-devadin.iam.gserviceaccount.com"
}

#create cloud router for NAT gateway
resource "google_compute_router" "router" {
  project = var.project
  name    = "${var.name}-nat-router"
  region  = var.location
  network = "test-1 "
}

#creating a nat gateway with terrafom module
module "nat_gateway" {
  source     = "terraform-google-modules/cloud-nat/google"
  version    = "~> 1.2"
  project_id = var.project
  region     = var.location
  router     = google_compute_router.router.name
  name       = "${var.name}-nat-gateway"
}


#####################output##############
output "kubernetes_cluster_host" {
  value       = google_container_cluster.cluster.endpoint
  description = "gke cluster host "


}
output "kubernetes_cluster_name" {
  value       = google_container_cluster.cluster.name
  description = "gke cluster name "

}




