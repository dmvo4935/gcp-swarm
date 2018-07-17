data "vault_generic_secret" "gcp-credentials" {
  path = "secret/gcp/eternal-centaur-185911"
}

variable "project_name" {
  default = "eternal-centaur-185911"
}

variable "public_key_path" {
  default = "id_rsa.pub"
}

variable "private_key_path" {
  default = "id_rsa"
}

variable "management_user" {
  default = "et4935"
}
