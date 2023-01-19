provider "google" {
  project = "cloud-service-benchmarking-22"
  region  = "europe-west1"
  zone    = "europe-west1-b" // belgium, low CO2
}

provider "cloudinit" {}

variable "ansible-ssh-key-file" {
  type = string
  description = "SSH public key for Ansible to use. E.g. ~/.ssh/id_ed25519.pub"
  default = "../.ssh/id_ed25519.pub"
}

variable "scenario" {
  type = object({
    name = string
    client_machine_type = string
    instance_machine_type = string
    instances = list(object({
      users = number # todo obsolete by using max(posting_users, listening_users) instead
      posting_users = number # number of users that post
      listening_users = number # number of users that listen
    }))
  })

  validation {
    condition = length([ for i in var.scenario.instances: i
      if i.users % 1 != 0 || i.listening_users % 1 != 0 || i.posting_users % 1 != 0
    ]) == 0
    error_message = "All user numbers must be integers."
  }

  validation {
    condition = length([ for i in var.scenario.instances: i
      if i.users < i.posting_users || i.users < i.listening_users
    ]) == 0
    error_message = "Number of listening users and number of posting users per instance must be less or equal the number of users of that instance."
  }

  description = "Benchmark scenario configuration."

  default = {
    name = "single-instance-default"
    client_machine_type = "e2-micro"
    instance_machine_type = "e2-standard-2"
    instances = [
      {
        users = 10
        posting_users = 10
        listening_users = 10
      }
    ]
  }
}

resource "google_compute_network" "vpc_network" {
  name                    = "mstdn-single-network"
  auto_create_subnetworks = "true"
}

data "template_file" "cloud_init_default" {
  template = file("cloud-init.yaml")
  vars = {
    ansibleSshKey = file(var.ansible-ssh-key-file)
    minicaRoot = file("../cert/minica.pem")
  }
}

data "template_file" "cloud_init_instance_extension" {
  template = file("mastodon.extend.cloud-init.yml")
  vars = {
    dockerCompose = file("../docker-compose.yml")
    nginxTemplate = file("../nginx.conf.template")
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
    merge_type = "list(append)+dict(recurse_array)+str()"
  }
  part {
    content_type = "text/jinja2"
    content = data.template_file.cloud_init_instance_extension.rendered
    merge_type = "list(append)+dict(recurse_array)+str()"
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
  count = length(var.scenario.instances)
  machine_type = var.scenario.instance_machine_type
  name         = format("%s-%d", var.scenario.name, count.index)
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
  machine_type = var.scenario.client_machine_type
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
  content = join("\n", concat([google_compute_instance.controller.name], google_compute_instance.instance.*.network_interface.0.access_config.0.nat_ip))
}

resource "local_file" "hosts" {
  filename = "hosts"
  content = join("\n", concat([google_compute_instance.controller.name], google_compute_instance.instance.*.name))
}

locals {
  secrets = [ for secret in slice(yamldecode(file("secrets.yaml")).secrets, 0, length(var.scenario.instances)) : "RAKE_SECRET_KEY: ${secret.rake-secret-key}\nRAKE_SECRET_OTP: ${secret.rake-secret-otp}\nVAPID_PRIVATE_KEY: ${secret.vapid-private-key}\nVAPID_PUBLIC_KEY: ${secret.vapid-public-key}" ]
}

resource "local_file" "ansible_hosts" {
  filename = "../hosts.ini"
  content = format("[all]\n%s\n%s\n\n[client]\n%s\n\n[instance]\n%s\n",
    join("\n", formatlist("%s", [google_compute_instance.controller.name])), # [all]
    join("\n", formatlist("%s", google_compute_instance.instance.*.name)), # [all]
    join("\n", formatlist("%s", [google_compute_instance.controller.name])), # [client]
    join("\n", formatlist("%s", google_compute_instance.instance.*.name)), # [instance]
  )
}

resource "local_file" "host_vars" {
  count = length(google_compute_instance.instance)
  filename = format("../playbooks/host_vars/%s", google_compute_instance.instance[count.index].name)
  content = local.secrets[count.index]
}
