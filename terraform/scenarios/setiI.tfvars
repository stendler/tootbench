
scenario = {
  name = "mastodon"
  debug = false
  client_machine_type = "e2-micro"
  instance_machine_type = "e2-standard-2"
  mastodon_version = "v3.5.5"
  instances = [
    {
      users = 30
      posting_users = 30
      listening_users = 30
    }
  ]
}
