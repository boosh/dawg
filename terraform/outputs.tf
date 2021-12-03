output "droplet_id" {
  value = digitalocean_droplet.wg.id
}

output "endpoint" {
  value = var.ydns_url
}

output "ip" {
  value = digitalocean_droplet.wg.ipv4_address
}
