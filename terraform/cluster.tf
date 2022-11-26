locals {
  tag_name           = "titans"
  region             = "europe-west1"
  pod_range_name     = "pod-ip-range"
  service_range_name = "service-ip-range"
  project_name       = "playground-369107"
  services_to_enable = ["compute.googleapis.com", "container.googleapis.com"]
}

# Enable Needed Project Services
resource "google_project_service" "titans_project" {
  for_each = toset(local.services_to_enable)
  project  = local.project_name
  service  = each.value
}

# Titans Network(VPC)
resource "google_compute_network" "titans_network" {
  name                    = "${local.tag_name}-network"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.titans_project]
}

# Titans Sub-Network
resource "google_compute_subnetwork" "titans_subnet" {
  name          = "${local.tag_name}-subnetwork"
  ip_cidr_range = "10.2.0.0/16"
  region        = local.region
  network       = google_compute_network.titans_network.id
  secondary_ip_range {
    range_name    = local.pod_range_name
    ip_cidr_range = "192.168.10.0/24"
  }
  secondary_ip_range {
    range_name    = local.service_range_name
    ip_cidr_range = "192.168.20.0/24"
  }
}

# Titans Firewall
resource "google_compute_firewall" "default" {
  name = "${local.tag_name}-firewall"
  network = google_compute_network.titans_network.name

  allow {
    protocol = "tcp"
    ports = ["80", "31079","31457"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# Titans Kubernetes Cluster
resource "google_container_cluster" "titans_cluster" {
  name       = "${local.tag_name}-cluster"
  location   = local.region
  network    = google_compute_network.titans_network.name
  subnetwork = google_compute_subnetwork.titans_subnet.name

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
}

## Handson Cluster Nodes
resource "google_container_node_pool" "titans_preemptible_nodes" {
  name       = "${local.tag_name}-node-pool"
  location   = local.region
  cluster    = google_container_cluster.titans_cluster.name
  node_count = 1
  node_locations = [
    "europe-west1-b",
    "europe-west1-c",
  ]
  node_config {
    preemptible  = true
    machine_type = "e2-medium"

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.titans-sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

## Titans Cluster Node Service Account
resource "google_service_account" "titans-sa" {
  account_id   = "${local.tag_name}-sa"
  display_name = "Hands On"
}
