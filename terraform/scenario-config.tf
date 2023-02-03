
variable "scenario" {
  type = object({
    name = string
    debug = bool
    client_machine_type = string
    instance_machine_type = string
    mastodon_version = string
    instances = list(object({
      users = number # todo obsolete by using max(posting_users, listening_users) instead
      posting_users = number # number of users that post
      listening_users = number # number of users that listen
    }))
    # todo maybe clients (?)
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

  description = <<-EOT
  Benchmark scenario configuration.

  - name: of the scenario and used as instance names and for the collected output file directory.
  - client_machine_type: gcp machine type for the client machine. Preferably many core less ram.
  - instance_machine_type: gcp machine type for the instances. Preferably multi-core and no burst machines.
  - instances: list of instances with per instance configuration
    - posting_users: number of users on this instance, creating posts
    - listening_users: number of users on this instance, listening to a feed stream
  EOT

  default = {
    name = "single-instance-default"
    debug = true
    client_machine_type = "e2-micro"
    instance_machine_type = "e2-standard-2"
    mastodon_version = "v4.0.2"
    instances = [
      {
        users = 10
        posting_users = 10
        listening_users = 10
      }
    ]
  }
}
