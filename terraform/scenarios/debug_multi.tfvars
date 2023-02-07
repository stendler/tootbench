
scenario = {
  name = "debug"
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
   ,{
      users = 5
      posting_users = 5
      listening_users = 5
    }
#   ,{
#      users = 10
#      posting_users = 10
#      listening_users = 10
#    }
  ]
}
