provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "pihole" {
  url      = "http://192.168.1.29:8081"
  password = var.pihole_password
}

provider "ovh" {
  endpoint           = "ovh-eu"
  application_key    = var.ovh_app_key
  application_secret = var.ovh_app_secret
  consumer_key       = var.ovh_consumer_key
}

data "ovh_me" "myaccount" {}

data "ovh_order_cart" "mycart" {
  ovh_subsidiary = data.ovh_me.myaccount.ovh_subsidiary
}
