resource "digitalocean_droplet" "wg" {
  image  = var.image
  name   = "wg"
  region = var.region
  size   = var.size
  ssh_keys = var.ssh_keys
  user_data = file("${path.module}/templates/user-data.txt")
}