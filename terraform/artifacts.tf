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

resource "local_file" "ansible_hosts" {
  filename = "../hosts.ini"
  content = format("[all]\n%s\n%s\n\n[client]\n%s\n\n[instance]\n%s\n",
    join("\n", formatlist("%s", [google_compute_instance.client.name])), # [all]
    join("\n", formatlist("%s", google_compute_instance.instance.*.name)), # [all]
    join("\n", formatlist("%s", [google_compute_instance.client.name])), # [client]
    join("\n", formatlist("%s", google_compute_instance.instance.*.name)), # [instance]
  )
}

resource "local_file" "host_vars" {
  count = length(google_compute_instance.instance)
  filename = format("../playbooks/host_vars/%s", google_compute_instance.instance[count.index].name)
  content = local.secrets[count.index]
}
