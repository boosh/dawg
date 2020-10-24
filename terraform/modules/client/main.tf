resource "null_resource" "client" {
  connection {
    type        = "ssh"
    user        = "root"
    host        = var.server_ip
    private_key = file("~/.ssh/id_rsa")
  }

  provisioner "remote-exec" {
    inline = [
      "/usr/local/bin/wg-add-client.sh -c ${var.ip} -k ${var.public_key} add ${var.name}"
    ]
  }
}