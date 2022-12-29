provider "google" {
  project = "cloud-service-benchmarking-22"
  region  = "europe-west1"
  zone    = "europe-west1-b" // belgium, low CO2
}

variable "ansible-ssh-key" {
  type = string
  description = "SSH public key for Ansible to use. E.g. contents of ~/.ssh/id_ed25519.pub"
}

resource "google_compute_network" "vpc_network" {
  name                    = "mstdn-single-network"
  auto_create_subnetworks = "true"
}

data "template_file" "user_data" {
  template = file("cloud-init.yaml")
  vars = {
    ansibleSshKey = var.ansible-ssh-key
  }
}

resource "google_compute_instance" "instance" {
  machine_type = "e2-micro"
  name         = "mstdn-single-instance"
  tags         = ["ssh"]

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
    }
  }

  metadata = {
    user-data = data.template_file.user_data.rendered
  }

  network_interface {
    network = google_compute_network.vpc_network.self_link
    access_config {
      # Include this section to give the VM an external IP address
      network_tier = "STANDARD"
    }
  }
}

resource "google_compute_firewall" "ssh" {
  name = "allow-ssh"
  allow {
    ports    = ["22"]
    protocol = "tcp"
  }
  direction     = "INGRESS"
  network       = google_compute_network.vpc_network.id
  priority      = 1000
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh"]
}
