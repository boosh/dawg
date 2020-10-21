resource "digitalocean_droplet" "wg" {
  image  = var.image
  name   = "wg"
  region = var.region
  size   = var.size
  ssh_keys = var.ssh_keys
  user_data = templatefile("${path.module}/templates/user-data.txt", {
    wg_init = base64encode(file("${path.module}/templates/wg-init.sh"))
  })
}