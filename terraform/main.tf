resource "digitalocean_droplet" "wg" {
  image  = var.image
  name   = "wg"
  region = var.region
  size   = var.size
  ssh_keys = var.ssh_keys
  user_data = templatefile("${path.module}/templates/user-data.txt", {
    ecdsa_public = var.ecdsa_public,
    ecdsa_private = var.ecdsa_private,
    wg_configure_server = base64encode(file("${path.module}/templates/wg-configure-server.sh"))
    wg_add_client = base64encode(file("${path.module}/templates/wg-add-client.sh"))
  })
}