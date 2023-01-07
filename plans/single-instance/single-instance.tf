provider "google" {
  project = "cloud-service-benchmarking-22"
  region  = "europe-west1"
  zone    = "europe-west1-b" // belgium, low CO2
}

provider "cloudinit" {}

variable "instance-name" {
  type = string
  default = "mstdn-single-instance"
}

variable "ansible-ssh-key-file" {
  type = string
  description = "SSH public key for Ansible to use. E.g. ~/.ssh/id_ed25519.pub"
  default = "../../.ssh/id_ed25519.pub"
}

variable "secrets" {
  type = object({
    rake-secret-key = string
    rake-secret-otp = string
    vapid-private-key = string
    vapid-public-key = string
  })
  description = "Secrets for th .env.production template.\nrake-secret-key & rake-secret-otp: `rake secret`\nvapid-private-key & vapid-public-key: `rake mastodon:webpush:generate_vapid_key`"
  sensitive = true
}

resource "google_compute_network" "vpc_network" {
  name                    = "mstdn-single-network"
  auto_create_subnetworks = "true"
}

data "template_file" "env_production" {
  template = file("../../.env.production.template")
  vars = {
    domain = var.instance-name
    rake-secret-key = var.secrets.rake-secret-key
    rake-secret-otp = var.secrets.rake-secret-otp
    vapid-private-key = var.secrets.vapid-private-key
    vapid-public-key = var.secrets.vapid-public-key
  }
}

data "template_file" "cloud_init_default" {
  template = file("cloud-init.yaml")
  vars = {
    ansibleSshKey = file(var.ansible-ssh-key-file)
    minicaRoot = file("../../cert/minica.pem")
  }
}

data "template_file" "cloud_init_instance_extension" {
  template = file("mastodon.extend.cloud-init.yml")
  vars = {
    dockerCompose = file("../../docker-compose.yml")
    minicaCert = file(format("../../cert/%s/cert.pem", var.instance-name))
    minicaKey = file(format("../../cert/%s/key.pem", var.instance-name))
    scriptCreateAdmin = file("../../scripts/createAdminUser.sh")
    scriptCreateUser = file("../../scripts/createUser.sh")
    nginxTemplate = file("../../nginx.conf.template")
    env_production = data.template_file.env_production.rendered
  }
}

data "template_file" "cloud_init_controller_extension" {
  template = file("controller.extend.cloud-init.yml")
  vars = { }
}

data "cloudinit_config" "instance" {
  gzip = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    content = data.template_file.cloud_init_default.rendered
  }
  part {
    content_type = "text/jinja2"
    content = data.template_file.cloud_init_instance_extension.rendered
  }
}

data "cloudinit_config" "controller" {
  gzip = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    content = data.template_file.cloud_init_default.rendered
    merge_type = "list(append)+dict(recurse_array)+str()"
  }
  part {
    content_type = "text/jinja2"
    content = data.template_file.cloud_init_controller_extension.rendered
    merge_type = "list(append)+dict(recurse_array)+str()"
  }
}

resource "google_compute_instance" "instance" {
  machine_type = "e2-medium"
  name         = var.instance-name
  tags         = ["ssh", "internal"
    #,"debug-extern"
  ]
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2210-amd64"
    }
  }

  metadata = {
    enable-guest-attributes = "TRUE"
    user-data = data.cloudinit_config.instance.rendered
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
    enable-guest-attributes = "TRUE"
    user-data = data.cloudinit_config.controller.rendered
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

resource "google_compute_firewall" "extern" {
  name = "allow-web-extern-debug"
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
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["debug-extern"]
}

resource "local_file" "ip" {
  filename = "ip"
  content = google_compute_instance.instance.network_interface.0.access_config.0.nat_ip
}

resource "local_file" "hosts" {
  filename = "hosts"
  content = join("\n", formatlist("%s", [google_compute_instance.controller.name, google_compute_instance.instance.name]))
}

// A variable for extracting the external IP address of the VM
output "Instance-IP" {
  value = google_compute_instance.instance.network_interface.0.access_config.0.nat_ip
}
