
variable "scenario-config" {
  type = object({
    instance_machine_type = string
    client_machine_type = string
    instances = list(object({
      name = string
      number_of_users = number
    }))
    # todo maybe clients (?)
  })

  default = {
    instance_machine_type = "e2-standard-2"
    client_machine_type = "e2-custom-4-2048"
    instances = [
      {
        name : "instance"
        number_of_users : 10
      },
      ]
  }
}
