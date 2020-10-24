resource "digitalocean_droplet" "wg" {
  image    = var.droplet_image
  name     = "wg"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = var.ssh_keys
  user_data = templatefile("${path.module}/templates/user-data.txt", {
    server_private_key  = var.server_private_key
    update_ydns         = base64encode(file("${path.module}/templates/update-ydns.sh"))
    wg_configure_server = base64encode(file("${path.module}/templates/wg-configure-server.sh"))
    wg_add_client       = base64encode(file("${path.module}/templates/wg-add-client.sh"))
  })
}

resource "null_resource" "accept_ssh_key" {
  provisioner "local-exec" {
    command = <<EOF
set -x
while :
do
  ssh-keygen -R ${digitalocean_droplet.wg.ipv4_address}
  ssh-keyscan -H ${digitalocean_droplet.wg.ipv4_address} >> ~/.ssh/known_hosts
  if [ $? -ne 0 ]; then
    echo "SSH keys not ready, sleeping"
    sleep 5
  else
    break
  fi
done
EOF
  }
}

resource "null_resource" "server_ready" {
  depends_on = [null_resource.accept_ssh_key]

  provisioner "local-exec" {
    command = <<EOF
set -x
while :
do
  make status ip=${digitalocean_droplet.wg.ipv4_address}
  if [ $? -ne 0 ]; then
    echo "Server not ready, sleeping"
    sleep 10
  else
    sleep 30      # let the server restart
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
