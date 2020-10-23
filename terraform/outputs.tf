output "ip" {
  value = digitalocean_droplet.wg.ipv4_address
}

output "endpoint" {
  value = var.ydns_url
}
