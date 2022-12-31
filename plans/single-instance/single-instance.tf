provider "google" {
  project = "cloud-service-benchmarking-22"
  region  = "europe-west1"
  zone    = "europe-west1-b" // belgium, low CO2
}

variable "ansible-ssh-key-file" {
  type = string
  description = "SSH public key for Ansible to use. E.g. ~/.ssh/id_ed25519.pub"
  default = "../../.ssh/id_ed25519.pub"
}

resource "google_compute_network" "vpc_network" {
  name                    = "mstdn-single-network"
  auto_create_subnetworks = "true"
}

data "template_file" "user_data" {
  template = file("cloud-init.yaml")
  vars = {
    ansibleSshKey = file(var.ansible-ssh-key-file)
  }
}

resource "google_compute_instance" "instance" {
  machine_type = "e2-medium"
  name         = "mstdn-single-instance"
  tags         = ["ssh", "internal"]
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2210-amd64"
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

resource "google_compute_instance" "controller" {
  machine_type = "e2-micro"
  name         = "controller"
  tags         = ["ssh", "internal"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2210-amd64"
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

resource "google_compute_firewall" "internal" {
  name = "allow-web-internal"
  allow {
    ports    = ["80", "443"]
    protocol = "tcp"
  }
  allow {
    protocol = "icmp"
  }
  direction     = "INGRESS"
  network       = google_compute_network.vpc_network.id
  priority      = 1000
  source_tags   = ["internal"]
  target_tags   = ["internal"]
}

// A variable for extracting the external IP address of the VM
output "Instance-IP" {
  value = google_compute_instance.instance.network_interface.0.access_config.0.nat_ip
}
