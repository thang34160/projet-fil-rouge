# Création de la ressource "type de ressource" "nom local a l'intérieur du code"



###   KEYCLOAK   ###

resource "keycloak_realm" "fil_rouge" {
  # nom qui apparait dans l'interface keycloak
  realm = "fil-rouge"
  # signifie "ce realm doit être actif dès sa création"
  enabled = true
  display_name = "Authentification Projet Fil Rouge"
}


# création de la connexion entre keycloak et le ldap via user federation
resource "keycloak_ldap_user_federation" "ldap_user_federation" {
  name     = "openldap"
  realm_id = keycloak_realm.fil_rouge.id
  # active la liaison avec le ldap
  enabled = true

  # champ ldap à utiliser par keycloack comme "nom d'utilisateur"
  username_ldap_attribute = "cn"
  # demander une explication pour ce champ
  rdn_ldap_attribute = "cn"
  # identifiant unique 
  uuid_ldap_attribute = "entryDN"
  # schema d'un utilisateur
  user_object_classes = [
    "inetOrgPerson",
    "posixAccount",
    "top"
  ]
  # adresse de la vm et le port de ldap
  connection_url = "ldap://192.168.122.23:389"
  # indique le groupe dans lequel les users seront stockés
  users_dn = "dc=thang,dc=com"
  # identifiants de l'admin
  bind_dn = "cn=admin,dc=thang,dc=com"
  # utiliser des variables pour ne pas coder le password en dur
  bind_credential = "adminpassword"

  connection_timeout = "5s"
  read_timeout       = "10s"
}

# Création du client vault dans keycloak
resource "keycloak_openid_client" "vault_client" {
  realm_id    = "keycloak_realm.fil_rouge.id"
  client_id   = "vault"
  name        = "Vault"
  enabled     = true
  access_type = "CONFIDENTIAL"

  valid_redirect_uris = [
    "http://192.168.122.23:8200/ui/vault/auth/oidc/oidc/callback",
  ]
}


###   VAULT   ###

## ressource "vault_jwt_auth_backend" trouvée avec IA: demander comment trouver ces infos san IA ?

# création de l'Authentication Methods 
resource "vault_auth_backend" "oidc" {
  type = "oidc"
  path = "oidc" # Chemin d'accès (ex: vault login -method=oidc)
}

# liaison de vault et keycloak 
resource "vault_jwt_auth_backend" "keycloak" {
  type               = "oidc"
  path               = "oidc" # Chemin d'accès (ex: vault login -method=oidc)
  oidc_discovery_url = "http://192.168.122.23:8080/realms/${keycloak_realm.fil_rouge.realm}"
  oidc_client_id     = keycloak_openid_client.vault_client.client_id
  oidc_client_secret = keycloak_openid_client.vault_client.client_secret
  default_role       = "admin-role"
}

resource "vault_jwt_auth_backend_role" "admin" {
  backend        = vault_jwt_auth_backend.keycloak.path
  role_name      = "admin-role"
  token_policies = ["default", "admin"]

  user_claim            = "sub"
  role_type             = "oidc"
  allowed_redirect_uris = ["http://192.168.122.23:8200/ui/vault/auth/oidc/oidc/callback"]
}


## gestion des secrets dans vault

# création du moteur de secret kv (key-value) et du chemin racine applications 
resource "vault_mount" "apps" {
  path        = "Applications"
  type        = "kv"
  options     = { version = "2" }
  description = "Stockage des secrets par application"
}

# creation du secret pour l application 1
resource "vault_kv_secret_v2" "app1_secret" {
  mount = vault_mount.apps.path
  name  = "app1/mon_secret"
  # transformation en json pour être lisible par vault
  data_json = jsonencode({
    # va chercher dans Apllication/app1/ le secret dont tu as besoin
    api_key = "12345-abcde"
  })
}

# creation du secret pour l application 2
resource "vault_kv_secret_v2" "app2_secret" {
  mount = vault_mount.apps.path
  name  = "app2/mon_secret"
  data_json = jsonencode({
    api_key = "12345-abcde"
  })
}