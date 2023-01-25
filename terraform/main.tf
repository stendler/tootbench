provider "google" {
  project = var.project-name
  region  = "europe-west1"
  zone    = "europe-west1-b" // belgium, low CO2
}

provider "cloudinit" {}

variable "project-name" {
  type = string
  default = "cloud-service-benchmarking-22"
}

variable "ansible-ssh-key-file" {
  type = string
  description = "SSH public key for Ansible to use. E.g. ~/.ssh/id_ed25519.pub"
  default = "../.ssh/id_ed25519.pub"
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
