
scenario = {
  name = "mastodon"
  debug = false
  client_machine_type = "e2-micro"
  instance_machine_type = "e2-custom-6-6144"
  mastodon_version = "v4.0.2"
  instances = [
    {
      users = 10
      posting_users = 10
      listening_users = 10
    }
  ]
}
