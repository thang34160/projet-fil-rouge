# Création de la ressource "type de ressource" "nom local a l'intérieur du code"



###   KEYCLOAK   ###

resource "keycloak_realm" "realm" {
  # nom qui apparait dans l'interface keycloak
  realm   = "master"
  # signifie "ce realm doit être actif dès sa création"
  enabled = true
}


# création de la connexion entre keycloak et le ldap via user federation
resource "keycloak_ldap_user_federation" "ldap_user_federation" {
  name     = "openldap"
  realm_id = keycloak_realm.realm.id
  # active la liaison avec le ldap
  enabled  = true

  # champ ldap à utiliser par keycloack comme "nom d'utilisateur"
  username_ldap_attribute = "cn"
  # demander une explication pour ce champ
  rdn_ldap_attribute      = "cn"
  # identifiant unique 
  uuid_ldap_attribute     = "entryDN"
  # schema d'un utilisateur
  user_object_classes     = [
    "inetOrgPerson",
    "posixAccount",
    "top"
  ]
  # adresse de la vm et le port de ldap
  connection_url          = "ldap://192.168.122.23:389"
  # indique le groupe dans lequel les users seront stockés
  users_dn                = "dc=thang,dc=com"
  # identifiants de l'admin
  bind_dn                 = "cn=admin,dc=thang,dc=com"
  # utiliser des variables pour ne pas coder le password en dur
  bind_credential         = "adminpassword"

  connection_timeout = "5s"
  read_timeout       = "10s"
}

# Création du client vault dans keycloak
resource "keycloak_openid_client" "vault_client" {
  realm_id              = "master"
  client_id             = "vault"
  name                  = "Vault"
  enabled               = true
  access_type           = "CONFIDENTIAL" 
  
  valid_redirect_uris = [
    "http://192.168.122.23:8200/ui/vault/auth/oidc/oidc/callback",
  ]
}


###   VAULT   ###

## code trouvé avec IA: demander comment trouver ces infos san IA

# création de l'Authentication Methods 
resource "vault_auth_backend" "oidc" {
  type = "oidc"
  path = "oidc/" # Chemin d'accès (ex: vault login -method=oidc)
}

# liaison de vault et keycloak 
resource "vault_jwt_auth_backend_config" "keycloak_config" {
  backend            = vault_auth_backend.oidc.path
  oidc_discovery_url = "http://192.168.122.23:8080/realms/master"
  oidc_client_id     = keycloak_openid_client.vault_client.client_id
  oidc_client_secret = keycloak_openid_client.vault_client.client_secret
  default_role       = "admin-role"
}

# créer un role dans vault
resource "vault_jwt_auth_backend" "oidc" {
  path = "oidc"
  default_role = "test-role"
}

resource "vault_jwt_auth_backend_role" "example" {
  backend         = vault_jwt_auth_backend.oidc.path
  role_name       = "admin-role"
  token_policies  = ["default", "admin"]

  user_claim            = "sub"
  role_type             = "oidc"
  allowed_redirect_uris = ["http://192.168.122.23:8200/ui/vault/auth/oidc/oidc/callback"]
}
