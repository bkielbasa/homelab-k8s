provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}

provider "ovh" {
  endpoint      = "ovh-eu"
  application_key    = "a80dd5cb6a2fc148"
  application_secret = "61930e68b0a1fd7e8077e8fcda51f485"
  consumer_key       = "bd755f3f462b78749ec5d3079c010eaf"
}

data "ovh_me" "myaccount" {}

data "ovh_order_cart" "mycart" {
  ovh_subsidiary = data.ovh_me.myaccount.ovh_subsidiary
}
