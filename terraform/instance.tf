data "template_file" "cloud_init_instance_extension" {
  template = file("mastodon.extend.cloud-init.yml")
  vars = {
    dockerCompose = file("../docker-compose.yml")
    nginxTemplate = file("../nginx.conf.template")
  }
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

resource "google_compute_instance" "instance" {
  count = length(var.scenario.instances)
  machine_type = var.scenario.instance_machine_type
  name         = format("%s-%d", var.scenario.name, count.index)
  tags         = ["ssh", "internal"
    , var.scenario.debug ? "debug-extern" : "prod"
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
