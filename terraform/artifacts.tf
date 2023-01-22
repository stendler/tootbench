resource "local_file" "ip" {
  filename = "ip"
  content = join("\n", concat([google_compute_instance.client.name], google_compute_instance.instance.*.network_interface.0.access_config.0.nat_ip))
}

resource "local_file" "hosts" {
  filename = "hosts"
  content = join("\n", concat([google_compute_instance.client.name], google_compute_instance.instance.*.name))
}

locals {
  secrets = [ for secret in slice(yamldecode(file("secrets.yaml")).secrets, 0, length(var.scenario.instances)) : "RAKE_SECRET_KEY: ${secret.rake-secret-key}\nRAKE_SECRET_OTP: ${secret.rake-secret-otp}\nVAPID_PRIVATE_KEY: ${secret.vapid-private-key}\nVAPID_PUBLIC_KEY: ${secret.vapid-public-key}" ]
}

# no ips needed - that is handled by gcloud compute ssh-config
resource "local_file" "ansible_hosts" {
  filename = "../hosts.ini"
  content = format("[all]\n%s\n%s\n\n[clients]\n%s\n\n[instances]\n%s\n",
    join("\n", formatlist("%s", [google_compute_instance.client.name])), # [all]
    join("\n", formatlist("%s", google_compute_instance.instance.*.name)), # [all]
    join("\n", formatlist("%s", [google_compute_instance.client.name])), # [clients]
    join("\n", formatlist("%s", google_compute_instance.instance.*.name)), # [instances]
  )
}

resource "local_file" "host_vars" {
  count = length(google_compute_instance.instance)
  filename = format("../playbooks/host_vars/%s", google_compute_instance.instance[count.index].name)
  content = format("%s\nIP: %s", local.secrets[count.index], google_compute_instance.instance[count.index].network_interface.0.access_config.0.nat_ip)
}
