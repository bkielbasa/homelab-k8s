variable pihole_password {
  type = string
  sensitive = true
}

variable ovh_app_key {
  type = string
  sensitive = true
}

variable ovh_app_secret {
  type = string
  sensitive = true
}

variable ovh_consumer_key {
  type = string
  sensitive = true
}

variable public_ip {
  type = string
  default = "212.87.243.126"
}

variable vault_token {
  type = string
  sensitive = true
}
