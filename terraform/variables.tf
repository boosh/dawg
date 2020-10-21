variable "do_token" {
  type = string
  description = "DigitalOcean API token"
}

variable "image" {
  type = string
  description = "Image to launch"
  default = "ubuntu-20-04-x64"
}

variable "region" {
  type = string
  default = "lon1"
}

variable "size" {
  type = string
  description = "Size of droplet"
  default = "s-1vcpu-1gb"
}

variable "ssh_keys" {
  type = list(number)
  description = "IDs of SSH keys to add"
}