# définition des outils dont terraform aura besoin
terraform {
  # renseignement des providers avec les informations du Terraform Registry
  required_providers {
    # il n'existe pas de provider officiel car ldap est un protocol. Le provider nitda/ldap permet de créer user, group, et organisationnal units
    ldap = {
      source  = "dodevops/ldap"
      version = "0.4.0"
    }

    keycloak = {
      source  = "keycloak/keycloak"
      version = "~>5.6.0"
    }

    vault = {
      source  = "hashicorp/vault"
      version = "~>5.6.0"
    }


  }

}

# connexion au provider grâce à la documentation officielle du provider dans terraform registry
provider "ldap" {
  ldap_url           = "ldaps://192.168.122.23:389"
  ldap_bind_dn       = "cn=admin,dc=thang,dc=com"
  ldap_bind_password = var.ldap_password
}


provider "keycloak" {
  client_id = "admin-cli"
  username  = "admin"
  password  = "password"
  url       = "http://192.168.122.23:8080"
}

provider "vault" {
  address = "http://192.168.122.23:8200"
  # assigner la valeur au token avec la commande terraform apply -var="vault_token=mon_root_token"
  token = var.vault_token
}


