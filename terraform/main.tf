resource "digitalocean_droplet" "wg" {
  image    = var.image
  name     = "wg"
  region   = var.region
  size     = var.size
  ssh_keys = var.ssh_keys
  user_data = templatefile("${path.module}/templates/user-data.txt", {
    wg_configure_server = base64encode(file("${path.module}/templates/wg-configure-server.sh"))
    wg_add_client       = base64encode(file("${path.module}/templates/wg-add-client.sh"))
    update_ydns         = base64encode(file("${path.module}/templates/update-ydns.sh"))
  })
}

resource "null_resource" "server_ready" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<EOF
set -x
while :
do
  make status ip=${digitalocean_droplet.wg.ipv4_address}
  if [ $? -ne 0 ]; then
    echo "Not ready, sleeping"
    sleep 10
  else
    break
  fi
done
EOF
  }
}

resource "null_resource" "update_ydns" {
  depends_on = [null_resource.server_ready]

  connection {
    type        = "ssh"
    user        = "root"
    host        = digitalocean_droplet.wg.ipv4_address
    private_key = file("~/.ssh/id_rsa")
  }

  provisioner "remote-exec" {
    inline = [
      "/usr/local/bin/update-ydns.sh ${var.ydns_url} ${var.ydns_credentials}"
    ]
  }
}

module "clients" {
  source     = "./modules/client"
  depends_on = [null_resource.server_ready]

  for_each   = var.clients
  ip         = each.value.ip
  name       = each.key
  public_key = each.value.public_key
  server_ip  = digitalocean_droplet.wg.ipv4_address
}
