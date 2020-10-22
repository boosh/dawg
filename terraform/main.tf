resource "digitalocean_droplet" "wg" {
  image  = var.image
  name   = "wg"
  region = var.region
  size   = var.size
  ssh_keys = var.ssh_keys
  user_data = templatefile("${path.module}/templates/user-data.txt", {
    wg_configure_server = base64encode(file("${path.module}/templates/wg-configure-server.sh"))
    wg_add_client = base64encode(file("${path.module}/templates/wg-add-client.sh"))
  })
}