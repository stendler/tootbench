from mastodon import Mastodon

client_name = "controller"
instance = "localhost"
#instance = "https://mstdn-single-instance"

app_id, app_secret = Mastodon.create_app(client_name=client_name, api_base_url=instance)

mastodon = Mastodon(client_id=app_id, client_secret=app_secret, api_base_url=instance)

print(str(mastodon))

