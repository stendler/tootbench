data "template_file" "cloud_init_controller_extension" {
  template = file("controller.extend.cloud-init.yml")
  vars = { }
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
