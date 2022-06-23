# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/using_gke_with_terraform#vpc-native-clusters

# Service account for gke node pool
resource "google_service_account" "gke_node_pool" {
  account_id   = "${var.cluster.name}-node-pool"
  display_name = "${var.cluster.name} node pool"
}

# Binding Roles to the service account
resource "google_project_iam_member" "gke_node_pool" {
  for_each = toset(var.node_roles)

  project = var.project.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_node_pool.email}"
}

# VPC network for VPC-nativce cluster
resource "google_compute_network" "gke_vpc" {
  name                    = var.cluster.name
  auto_create_subnetworks = false
}

# Sub network for VPC-native cluster
# REF: https://cloud.google.com/kubernetes-engine/docs/how-to/flexible-pod-cidr
resource "google_compute_subnetwork" "gke_subnet" {
  name          = "gke-subnet"
  ip_cidr_range = var.network.primary_ip_range
  region        = var.project.region
  network       = google_compute_network.gke_vpc.id
  secondary_ip_range = [
    {
      range_name    = "pod-range"
      ip_cidr_range = var.network.pod_range
    },
    {
      range_name    = "services-range"
      ip_cidr_range = var.network.service_range
    },
  ]
  private_ip_google_access = true
}

# GKE cluster
resource "google_container_cluster" "gke_cluster" {
  name     = var.cluster.name
  location = var.project.zone

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  # vvv For VPC-native cluster
  network    = google_compute_network.gke_vpc.id
  subnetwork = google_compute_subnetwork.gke_subnet.id

  ip_allocation_policy {
    cluster_secondary_range_name  = google_compute_subnetwork.gke_subnet.secondary_ip_range.0.range_name
    services_secondary_range_name = google_compute_subnetwork.gke_subnet.secondary_ip_range.1.range_name
  }
}

# Separately Managed Node Pool
resource "google_container_node_pool" "gke_node_pool" {
  name       = "${google_container_cluster.gke_cluster.name}-node-pool"
  location   = var.project.zone
  cluster    = google_container_cluster.gke_cluster.name
  node_count = var.cluster.node_count

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    preemptible  = var.cluster.preemptible
    machine_type = var.cluster.machine_type

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.gke_node_pool.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

