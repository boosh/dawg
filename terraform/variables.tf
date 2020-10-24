variable "clients" {
  type = map(object({
    ip         = string
    public_key = string
  }))
}

variable "do_token" {
  type        = string
  description = "DigitalOcean API token"
}

variable "droplet_image" {
  type        = string
  description = "Image to launch"
  default     = "ubuntu-20-04-x64"
}

variable "droplet_region" {
  type    = string
  default = "lon1"
}

variable "droplet_size" {
  type        = string
  description = "Size of droplet"
  default     = "s-1vcpu-1gb"
}

variable "server_private_key" {
  type        = string
  description = "Optional private-key to push onto the server"
  default     = ""
}

variable "server_preshared_key" {
  type        = string
  description = "Optional preshared-key to push onto the server"
  default     = ""
}

variable "ssh_keys" {
  type        = list(number)
  description = "IDs of SSH keys to add (get them from the DO API)"
}

variable "ydns_credentials" {
  type        = string
  description = "Credentials in the form 'username:password' (password can also be an API key)"
}

variable "ydns_url" {
  type        = string
  description = "Full URL, e.g. example.ydns.eu"
}
