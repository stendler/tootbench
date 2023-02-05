
scenario = {
  name = "mastodon"
  debug = false
  client_machine_type = "e2-micro"
  instance_machine_type = "e2-highcpu-4"
  mastodon_version = "v3.5.5"
  instances = [
    {
      users = 10
      posting_users = 10
      listening_users = 10
    }
  ]
}
