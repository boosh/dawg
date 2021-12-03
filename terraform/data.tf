data "digitalocean_droplet_snapshot" "snapshot" {
  count       = var.use_snapshot ? 1 : 0
  name_regex  = "^${var.snapshot_name}"
  region      = var.droplet_region
  most_recent = true
}