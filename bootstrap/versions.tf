terraform {
  required_version = "1.17.2"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.109.0"
    }
  }
}
