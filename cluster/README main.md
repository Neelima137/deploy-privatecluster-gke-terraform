Lets understand how the main.tf file works ,The terraform script provisions  Google Cloud resources to create a private Kubernetes (GKE) cluster with a jump host, a NAT gateway, and the associated network and security settings. Here's a breakdown of what each part of the script is doing:

1. Google Compute Network Resource
```
resource "google_compute_network" "test-1" {
  name                    = var.name
  auto_create_subnetworks = false
}
```

Here we are creating a VPC network with the name provided in var.name(default-' test-1') and ensures that subnetworks are not auto-created. This allows us to define the subnetwork manually.

![image](https://github.com/user-attachments/assets/9cd6a62b-2b4d-4a62-8e88-5be45503bec5)


3. Google Compute Subnetwork Resource
```
resource "google_compute_subnetwork" "test1-1" {
  name          = "${var.name}-subnet"
  region        = var.location
  ip_cidr_range = "10.0.0.0/24"
  network       = google_compute_network.test-1.name
}
```

This creates a subnetwork (test1-1) in the region defined by var.location(default - 'us-central1') and assigns it an IP range of 10.0.0.0/24. The subnetwork is linked to the previously created VPC network (test-1).

![image](https://github.com/user-attachments/assets/4622a4ef-9aaf-4385-a384-47c236dd84fe)


4. Google Kubernetes Engine (GKE) Cluster Resource
```
resource "google_container_cluster" "cluster" {
  name                     = "${var.name}-cluster"
  location                 = var.location
  initial_node_count       = 1
  network                  = google_compute_network.test-1.name     
  subnetwork               = google_compute_subnetwork.test1-1.name 
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
```
This sets up a GKE cluster within the private network and subnet we defined earlier:

Private cluster configuration: The cluster is configured as a private cluster, where nodes and master API are not accessible from the public internet.
IP allocation policy: The IP ranges for the cluster and services are configured for the cluster.
Master authorized networks: Only the IP range 10.0.0.7/32 is allowed to access the Kubernetes master API.

![image](https://github.com/user-attachments/assets/1d4bb38b-8ee8-472d-bfbe-d9a1943b40fc)
![image](https://github.com/user-attachments/assets/6eed9b43-7ca1-4fcc-bd65-7d05677e1e50)
![image](https://github.com/user-attachments/assets/340f95e0-e391-4fea-9b07-cd77bbd72c51)


4. Service Account Resource
```
resource "google_service_account" "service_account" {
  account_id   = "service-account"
  display_name = "service-account-name"
}
```
This creates a service account named service-account, which will be used by the GKE nodes to access Google Cloud services. You can skip this step if you don't want to specify a custom service account; in that case, the nodes will use the default service account instead.

5. Google Container Node Pool Resource
```
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
```
This creates a node pool within the GKE cluster. It uses preemptible e2-medium VMs, with OAuth scopes to access Cloud resources (like logging and monitoring). The service account defined earlier is assigned to the node pool.
![image](https://github.com/user-attachments/assets/347609b6-04ef-4daf-bea3-8065ef58bd8b)


6. Internal IP Address for Jump Host
```
resource "google_compute_address" "internal_ip" {
  project      = var.project
  address_type = "INTERNAL"
  region       = var.location
  subnetwork   = "${var.name}-subnet"
  name         = "${var.name}-my-ip"
  address      = "10.0.0.7"
  description  = "an internal ip address for jump host"
}
```
This creates an internal IP address (10.0.0.7) within the subnet you defined earlier. This IP will be used by the jump host to access resources securely.
![image](https://github.com/user-attachments/assets/1867d166-b06a-468e-946c-ad92be32fbb7)


8. Jump Host (VM Instance)
```
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
```

This creates a VM instance that acts as a "jump host" (a secure entry point) with the internal IP address 10.0.0.7. The jump host allows authorized users to SSH into the GKE cluster via a secure connection.

![image](https://github.com/user-attachments/assets/0473976b-e28c-402e-b3e0-382f0a997a8a)


8. Firewall Rule for Jump Host Access via IAP
hcl
Copy
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
This firewall rule allows SSH (port 22) access from the IP range 36.235.240.0/20, which is the IP range for Google Cloud IAP (Identity-Aware Proxy), enabling secure SSH access to the jump host.
![image](https://github.com/user-attachments/assets/11ee9cb2-91f3-4461-9ec8-95eeba982ad9)


10. IAM Permission for IAP SSH Access
```
resource "google_project_iam_member" "permissions" {
  project = var.project
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:terraform-demo@<<project-id>>.iam.gserviceaccount.com"
}
```
This IAM binding grants a service account (terraform-demo@cts07-devadin.iam.gserviceaccount.com) the ServiceAccountTokenCreator role, enabling the service account to use IAP for SSH access.
<img src="blob:chrome-untrusted://media-app/6b8c6eab-8bb3-430e-955b-860bbc1efad0" alt="Screenshot 2025-02-15 7.06.28 PM.png"/>![image](https://github.com/user-attachments/assets/e92a013a-e985-4e65-8e9a-c757380f8384)


11. Cloud Router Resource
```
resource "google_compute_router" "router" {
  project = var.project
  name    = "${var.name}-nat-router"
  region  = var.location
  network = "test-1"
}
```
This creates a Cloud Router that will be used for configuring a NAT gateway.

![image](https://github.com/user-attachments/assets/edb7c0c3-b977-4f45-96d2-8f9ee01ea3eb)


12. NAT Gateway with Terraform Module
```
module "nat_gateway" {
  source     = "terraform-google-modules/cloud-nat/google"
  version    = "~> 1.2"
  project_id = var.project
  region     = var.location
  router     = google_compute_router.router.name
  name       = "${var.name}-nat-gateway"
}
```
This uses a Terraform module to create a NAT gateway that allows outbound internet access for private GKE nodes.

![image](https://github.com/user-attachments/assets/a7351baa-ce1e-4b88-86e0-a1017025bdf7)


Outputs
```
output "kubernetes_cluster_host" {
  value       = google_container_cluster.cluster.endpoint
  description = "gke cluster host"
}
output "kubernetes_cluster_name" {
  value       = google_container_cluster.cluster.name
  description = "gke cluster name"
}
```
These outputs provide the GKE cluster's endpoint and name, which can be used by other configurations or scripts to interact with the cluster.

You can create an outputs.tf file to define and manage your outputs separately, which helps with organizing your Terraform configuration.

By moving your outputs to a dedicated outputs.tf file, you make it easier to manage and reference them in other modules or scripts. Here's an example of how you can structure the outputs.tf file

