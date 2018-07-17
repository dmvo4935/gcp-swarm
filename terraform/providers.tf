terraform {
  backend "consul" {
    address = "mycpe-consul.k8s.local:30501"
    path    = "gcp/eternal-centaur-185911"
    scheme  = "http"
  }
}

provider "vault" {
  address = "http://vault.k8s.local"
}

provider "google" {
  credentials = "${data.vault_generic_secret.gcp-credentials.data_json}"
  project     = "eternal-centaur-185911"
  region      = "europe-west1"
}
