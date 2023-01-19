
scenario = {
  name = "debug-single-instance"
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
