# Sécuriser le portail et les API IRIS avec Keycloak

Procédure pas à pas, dans l'ordre. Chaque étape indique **comment vérifier** qu'elle a réussi.
Tout ce qui est décrit ici a été exécuté et testé **en local** (conteneur `iris-health-training-dev`,
IRIS for Health 2026.1), sauf mention « non testé ».

- [1. Ce que l'on met en place](#1-ce-que-lon-met-en-place)
- [2. Prérequis](#2-prérequis)
- [3. Mise en place, étape par étape](#3-mise-en-place-étape-par-étape)
- [4. Vérifications de bout en bout](#4-vérifications-de-bout-en-bout)
- [Scénario de démonstration](#scénario-de-démonstration-10-minutes)
- [5. Gérer les utilisateurs et les rôles](#5-gérer-les-utilisateurs-et-les-rôles)
- [6. Accès de secours](#6-accès-de-secours-break-glass)
- [7. Reconstruire l'image IRIS](#7-reconstruire-limage-iris)
- [8. Dépannage](#8-dépannage)
- [9. Avant AWS / production](#9-avant-aws--production)
- [10. Fichiers du dépôt](#10-fichiers-du-dépôt)

---

## 1. Ce que l'on met en place

```
                         HTTPS (443, nginx)
 Navigateur ───────────────────────────────────────────────┐
                                                           ▼
   1. /iris-health-training-dev/csp/sys/...        ┌──────────────┐  auth_request   ┌───────────────┐
      (portail de gestion)  ─────────────────────► │    nginx     │ ──────────────► │ oauth2-proxy  │
   2. pas de session : 302 vers Keycloak           │ (TLS, 443)   │ ◄────────────── │ (cookie de    │
   3. connexion Keycloak (code + PKCE)             └──────┬───────┘  jeton d'accès  │  session)     │
   4. nginx ajoute  Authorization: Bearer <jeton>         │                         └──────┬────────┘
                                                          ▼                                │ OIDC
 Applications / outils (HL7 HTTP, API)            ┌──────────────┐                  ┌──────▼────────┐
   Authorization: Bearer <jeton> ───────────────► │ Web Gateway  │                  │   Keycloak    │
   (obtenu par client_credentials)                └──────┬───────┘                  │ realm « iris »│
                                                         ▼                          └───────────────┘
                                                 ┌──────────────┐
                                                 │     IRIS     │  resource server « keycloak-iris-api »
                                                 │              │  - vérifie la signature du JWT (JWKS)
                                                 └──────────────┘  - audience = iris-api
                                                                   - utilisateur = preferred_username
                                                                   - rôles IRIS = revendication « roles »
```

Deux chemins d'accès, **un seul mécanisme côté IRIS** (le jeton Keycloak) :

| Accès | Qui s'authentifie | Comment |
|---|---|---|
| Portail de gestion (navigateur) | une personne | `oauth2-proxy` fait la connexion Keycloak et transmet le jeton à IRIS |
| API HTTP (services HL7, REST, FHIR) | une application | l'appelant obtient un jeton (`client_credentials`) et l'envoie en `Bearer` |

Les rôles Keycloak deviennent des rôles IRIS **du même nom** (aucun n'est `%All`) :

| Rôle Keycloak = rôle IRIS | Accorde (rôles IRIS) | Pour quoi faire |
|---|---|---|
| `iris-admin` | `%Manager`, `Interop_Operator_Role` | administrer l'instance ; exploiter l'interopérabilité (accès aux espaces `DGLAB`, `TRAINING`…) |
| `iris-developer` | `%Developer` | développer |
| `iris-operator` | `%Operator` | exploitation système |
| `iris-viewer` | `Interop_Viewer_Role` | consulter l'interopérabilité (bases en lecture) |

`Interop_Operator_Role` et `Interop_Viewer_Role` ne sont **pas** créés par ce mécanisme : ils viennent du setup du projet
(`adm.utils`, `SecurityRoles.xml`) et portent les droits sur les bases des espaces (`%DB_DGLAB_*`, `%DB_TRAINING_*`…) et sur les
ressources `%Ens_*`. Si l'un d'eux n'existe pas encore, `adm.oidc` ne l'accorde pas, affiche un avertissement et l'accorde au passage suivant
de `./configure-oidc.sh`.

> **Les rôles sont lus à l'ouverture de la session IRIS.** Après un changement de rôles, l'utilisateur doit se déconnecter du portail
> (**Logout**) et se reconnecter, sinon sa session garde les anciens droits (le sélecteur d'espaces ne montre alors ni `DGLAB` ni `TRAINING`).

L'utilisateur IRIS est créé automatiquement à la **première connexion réussie** (nom = `preferred_username`) : un compte Keycloak qui ne s'est
jamais connecté n'existe pas encore dans IRIS (*Sécurité > Utilisateurs*). C'est normal.

---

## 2. Prérequis

- Docker et Docker Compose v2 ; `openssl` ; `python3`.
- Conteneurs de l'application démarrés avec le projet Compose `iris-health-training`
  (`docker network ls` doit montrer `iris-health-training_default`).
- Une clé de licence IRIS valide dans `iris/key/iris.key` (cf. `deploy-key.sh` pour la renouveler).
- Le fichier `.env` du dépôt (déjà présent : `IRIS_INSTANCE_NAME`, `WEBGATEWAY_PORT_HTTPS`…).

> **Important** — Les commandes `docker compose` ci-dessous utilisent toujours `-p iris-health-training`.
> Sans cela, Compose déduit le nom du projet du dossier et ne reconnaît pas les conteneurs existants.

---

## 3. Mise en place, étape par étape

> **Exécuter sans terminal** — Les blocs ```` ```http ```` de ce document sont des requêtes pour l'extension **REST Client** de VS Code
> (`humao.rest-client`). Cliquez sur **Send Request** au-dessus de la requête (ou `Ctrl/Cmd+Alt+R`). Le même contenu est dans
> [`keycloak/test-api.http`](../keycloak/test-api.http), où le lien est garanti : si **Send Request** n'apparaît pas dans ce fichier `.md`, ouvrez celui-là.
> Les secrets sont lus dans `keycloak/.env` (lien vers `keycloak/secrets.env`, créé par `./keycloak/init-secrets.sh`) ; aucun mot de passe n'est écrit dans les fichiers.


### Étape 1 — Générer les secrets (une seule fois)

```bash
./keycloak/init-secrets.sh
```

Crée `keycloak/secrets.env` (droits 600, ignoré par git) : mot de passe admin Keycloak, secrets des clients
`iris-portal` et `iris-service`, mot de passe initial des utilisateurs de démo, clé de cookie d'`oauth2-proxy`.
Le script n'écrase jamais une valeur existante : on peut le relancer après une mise à jour.

**Vérifier** : `ls -l keycloak/secrets.env` → `-rw-------`.
**Ne jamais commiter ce fichier** (il est dans `.gitignore`).

### Étape 2 — Certificat TLS local

```bash
./nginx/make-local-cert.sh
```

Crée un certificat auto-signé pour `localhost` dans `nginx/certs/` (ignoré par git). Le navigateur affichera un
avertissement la première fois : c'est normal en local. Pour AWS, voir [§9](#9-avant-aws--production).

### Étape 3 — Faire connaître le nom `keycloak` à votre navigateur

L'émetteur (`iss`) des jetons est `http://keycloak:8180/realms/iris`. Le même nom doit être résolu par le navigateur
**et** par les conteneurs (Docker le résout déjà). Sur la machine qui porte le navigateur, ajouter :

```bash
echo "127.0.0.1 keycloak" | sudo tee -a /etc/hosts
```

**Vérifier** : `ping -c1 keycloak` répond depuis `127.0.0.1`.

### Étape 4 — Démarrer Keycloak

```bash
docker compose -p iris-health-training up -d --no-deps keycloak
```

Le royaume `iris` (rôles, clients, utilisateurs de démo) est importé depuis `keycloak/realm-iris.json` au premier démarrage.
Keycloak est lancé en mode développement (`start-dev`, base H2 intégrée) : **pas pour la production**.

**Vérifier** (compter ~10 s) :

```http
@keycloak = http://keycloak:8180

GET {{keycloak}}/realms/iris/.well-known/openid-configuration
```

Résultat attendu : **200**, avec `"issuer":"http://keycloak:8180/realms/iris"` et `S256` dans `code_challenge_methods_supported`.

Pour vérifier aussi que le **conteneur IRIS** joint Keycloak (terminal, optionnel) :

```bash
docker exec iris-health-training-dev python3 -c "import urllib.request;print(urllib.request.urlopen('http://keycloak:8180/realms/iris/.well-known/openid-configuration').status)"
```

Résultat attendu : `200`.

Console d'administration : <http://keycloak:8180/> — utilisateur `admin`, mot de passe = `KC_BOOTSTRAP_ADMIN_PASSWORD` de `keycloak/secrets.env`.

### Étape 5 — Configurer IRIS

La classe `adm.oidc` (fichier `iris/src/adm/oidc.cls`) crée, de façon **idempotente** :

1. les quatre rôles IRIS (`iris-admin`…), avec les rôles qu'ils accordent ; un rôle déjà créé est **mis à jour** si sa définition a changé ;
2. la définition du serveur OAuth 2.0 « Keycloak » (endpoints explicites, sans découverte, donc sans que Keycloak soit démarré) ;
3. le resource server `keycloak-iris-api` (audience `iris-api`, validation locale du JWT, utilisateur = `preferred_username`, rôles = `roles`) et son *mapping* sur le service `%Service_WebGateway` ;
4. la méthode **OAuth2** sur les applications web : `/csp/healthshare/dglab`, `/csp/healthshare/training` et **les cinq applications du portail** (`/csp/sys`, `/exp`, `/mgr`, `/op`, `/sec`). Le mot de passe reste actif sur chacune.

Sur un conteneur **existant** :

```bash
./configure-oidc.sh --target local --instance dev
```

Le script demande un utilisateur et un mot de passe IRIS. Pour l'exécuter sans invite, définir `IRIS_LOGIN_USER` et `IRIS_LOGIN_PASSWORD` avant la commande.

**Vérifier** : la sortie se termine par `adm.oidc.Configure: OK`. Relancer la commande ne doit rien recréer
(`already exists` / `already enabled`).

> Pour une **nouvelle image** (volumes neufs), la même classe est appelée à la fin de `iris/iris.script` : voir [§7](#7-reconstruire-limage-iris).

### Étape 6 — Activer HTTPS sur nginx

`nginx/tls.conf` (HTTPS, en-têtes de sécurité, protection du portail) et les montages sont déjà dans `docker-compose.yml`.
Recréer le conteneur pour les prendre en compte (coupure de quelques secondes sur le port 80) :

```bash
docker compose -p iris-health-training up -d --no-deps nginx
```

**Vérifier** :

```http
GET http://localhost/app/
```

Résultat attendu : **200**. Pour contrôler aussi la version de TLS (terminal, optionnel) :

```bash
echo | openssl s_client -connect localhost:443 2>/dev/null | grep Protocol
```

Résultat attendu : `Protocol : TLSv1.3`.

### Étape 7 — Démarrer oauth2-proxy

```bash
docker compose -p iris-health-training up -d --no-deps oauth2-proxy
docker exec iris-health-training-nginx nginx -t && docker exec iris-health-training-nginx nginx -s reload
```

(`nginx -t` échoue tant qu'`oauth2-proxy` n'existe pas : le démarrer **avant** de recharger nginx.)

**Vérifier** : un accès au portail sans session redirige vers Keycloak.

```http
# @no-redirect
GET https://localhost/iris-health-training-dev/csp/sys/UtilHome.csp
```

Résultat attendu : **302** avec un en-tête `Location: http://keycloak:8180/realms/iris/protocol/openid-connect/auth?…code_challenge_method=S256…`.
Si REST Client refuse le certificat auto-signé local, ajouter `"http.proxyStrictSSL": false` dans les réglages de VS Code.

---

## 4. Vérifications de bout en bout

### 4.1 Le portail dans un navigateur

1. Ouvrir <https://localhost/iris-health-training-dev/csp/sys/UtilHome.csp> (accepter l'avertissement du certificat).
2. Vous êtes redirigé vers Keycloak : connectez-vous avec `iris.admin` et le mot de passe `IRIS_DEMO_USER_PASSWORD`
   de `keycloak/secrets.env`. Keycloak **ne demande pas** de changer ce mot de passe à la première connexion, bien que le fichier
   d'import le prévoie (`temporary: true`) : vérifié avec `iris.viewer`. Si vous voulez l'imposer, ajoutez l'action requise
   *Update Password* à l'utilisateur dans la console Keycloak.
3. Vous arrivez sur **IRIS - Home / Management Portal**. Dans le portail, *Système > Sécurité > Utilisateurs* montre l'utilisateur
   créé à la volée avec le rôle `iris-admin`.

Résultats observés en test (utilisateurs jetables, supprimés ensuite) :

| Utilisateur Keycloak (rôle) | Page d'accueil | Page *Users* (`/csp/sys/sec`) |
|---|---|---|
| `iris-admin` | ouverte | ouverte |
| `iris-viewer` | ouverte | **403 Forbidden** |
| sans connexion | redirigé vers Keycloak | redirigé vers Keycloak |

### 4.2 Une API protégée par jeton

Ces requêtes s'enchaînent : la première obtient un jeton auprès de Keycloak, les suivantes l'utilisent
(`{{token}}`). Cliquez sur **Send Request** dans l'ordre. Le message HL7 est une requête LAB-27 (QBP^Q11).

```http
@keycloak = http://keycloak:8180
@iris = http://localhost
@namespace = dglab

# @name login
POST {{keycloak}}/realms/iris/protocol/openid-connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials&client_id=iris-service&client_secret={{$dotenv IRIS_SERVICE_CLIENT_SECRET}}

###
@token = {{login.response.body.$.access_token}}

### Jeton valide
# @no-cookie-jar
POST {{iris}}/iris-health-training-dev/csp/healthshare/{{namespace}}/EnsLib.HL7.Service.HTTPService.cls?CfgItem=LAW%20LAB-27%20Query%20for%20AWOS%20-%20HTTP
Authorization: Bearer {{token}}
Content-Type: text/plain

MSH|^~\&|ANALYZER|LAB|LIS|LAB|20261113190000||QBP^Q11^QBP_Q11|QBP1|P|2.5.1|||NE|AL||UNICODE UTF-8|||LAB-27^IHE
QPD|WOS^Work Order Step^IHE_LABTF|Q1|CT99
RCP|I||R

### Jeton falsifié
# @no-cookie-jar
POST {{iris}}/iris-health-training-dev/csp/healthshare/{{namespace}}/EnsLib.HL7.Service.HTTPService.cls?CfgItem=LAW%20LAB-27%20Query%20for%20AWOS%20-%20HTTP
Authorization: Bearer {{token}}x
Content-Type: text/plain

MSH|^~\&|ANALYZER|LAB|LIS|LAB|20261113190000||QBP^Q11^QBP_Q11|QBP1|P|2.5.1|||NE|AL||UNICODE UTF-8|||LAB-27^IHE
QPD|WOS^Work Order Step^IHE_LABTF|Q1|CT99
RCP|I||R

### Sans identifiant
# @no-cookie-jar
POST {{iris}}/iris-health-training-dev/csp/healthshare/{{namespace}}/EnsLib.HL7.Service.HTTPService.cls?CfgItem=LAW%20LAB-27%20Query%20for%20AWOS%20-%20HTTP
Content-Type: text/plain

MSH|^~\&|ANALYZER|LAB|LIS|LAB|20261113190000||QBP^Q11^QBP_Q11|QBP1|P|2.5.1|||NE|AL||UNICODE UTF-8|||LAB-27^IHE
QPD|WOS^Work Order Step^IHE_LABTF|Q1|CT99
RCP|I||R

### Page d'administration avec le compte machine (aucun rôle Keycloak)
# @no-cookie-jar
GET {{iris}}/iris-health-training-dev/csp/sys/sec/%25CSP.UI.Portal.Users.zen
Authorization: Bearer {{token}}
```

Résultats attendus (observés sur `http://localhost`, port 80, qui accepte aussi le jeton en clair ; voir [§9](#9-avant-aws--production)) :

| Requête | Résultat attendu | Ce que cela montre |
|---|---|---|
| jeton (`login`) | **200**, un `access_token` | Keycloak authentifie le client `iris-service` |
| Jeton valide | **200**, message `RSP^K11` (`MSA\|AA`, `QAK\|Q1\|OK`) | IRIS accepte le jeton : authentification |
| Jeton falsifié | **200**, page HTML « Login IRIS », pas de `RSP^K11` | la signature invalide est rejetée |
| Sans identifiant | **200**, page HTML « Login IRIS », pas de `RSP^K11` | l'API n'est plus ouverte à tous |
| Page d'administration, compte machine | **403** | authentifié mais non autorisé : aucun rôle IRIS |

**Pourquoi `# @no-cookie-jar` ?** REST Client conserve les cookies d'une requête à l'autre. La requête « jeton valide » fait ouvrir une session
IRIS, dont le cookie serait renvoyé aux suivantes : « sans identifiant » ne serait alors plus sans identifiant et recevrait elle aussi le `RSP^K11`
(constaté). Cette métadonnée désactive les cookies pour la requête ; ne la retirez pas.

Le statut `200` des deux requêtes rejetées est normal : IRIS répond par sa page de connexion et pas par un `401`. C'est le contenu de la
réponse (« Login IRIS », pas de `RSP^K11`) qui prouve le rejet.

Pour voir l'autorisation à l'œuvre, donnez le rôle `iris-admin` au *service account* du client `iris-service` dans Keycloak, relancez la
requête `login` pour obtenir un nouveau jeton, puis la dernière requête : la page s'ouvre. Retirez ensuite ce rôle.

**Version terminal** (même test, en une commande, avec contrôle automatique du résultat) :

```bash
./keycloak/test-api.sh
```

Le script affiche `OK` ou `ECHEC` pour chacun des trois cas (jeton valide, jeton falsifié, sans jeton).

> Un compte **machine** (`service-account-iris-service`) n'a aucun rôle Keycloak par défaut : il est authentifié mais n'a
> pas de rôle IRIS. Pour lui donner des droits, ajouter un rôle au *service account* du client `iris-service`
> (Keycloak > Clients > iris-service > Service accounts roles).

---

## Scénario de démonstration (10 minutes)

Objectif : montrer **qui est l'utilisateur** (authentification par Keycloak) et **ce qu'il a le droit de faire** (autorisation par les rôles).
Prérequis : étapes 1 à 7 faites, `127.0.0.1 keycloak` dans `/etc/hosts`. Les mots de passe sont dans `keycloak/secrets.env`
(`IRIS_DEMO_USER_PASSWORD`, commun aux trois comptes de démo ; aucun changement de mot de passe n'est exigé à la première connexion).

| # | Action | Ce que l'on montre |
|---|---|---|
| 1 | Ouvrir `https://localhost/iris-health-training-dev/csp/sys/UtilHome.csp` dans une fenêtre privée | pas de session : redirection vers la page de connexion **Keycloak**, pas vers IRIS |
| 2 | Se connecter en `iris.viewer` | accès au portail (page d'accueil) : l'utilisateur est authentifié |
| 3 | Ouvrir *Système > Sécurité > Utilisateurs* (`.../csp/sys/sec/%25CSP.UI.Portal.Users.zen`) | **403** : `iris-viewer` n'a pas le droit d'administrer la sécurité (autorisation) |
| 4 | Se déconnecter (`https://localhost/oauth2/sign_out`), puis se connecter en `iris.admin` | même page : **ouverte**, parce que le rôle `iris-admin` est accordé |
| 5 | Dans le portail IRIS, *Sécurité > Utilisateurs* | l'utilisateur `iris.admin` a été **créé automatiquement**, avec le seul rôle `iris-admin` (pas `%All`) |
| 5 bis | Avec `iris.admin`, choisir l'espace `DGLAB` ou `TRAINING` (sélecteur d'espaces) puis *Interoperability > Configure > Production* | l'administrateur exploite l'interopérabilité (`Interop_Operator_Role`) ; avec `iris.viewer` la même page est visible en consultation (`Interop_Viewer_Role`) |
| 6 | Dans la console Keycloak (`http://keycloak:8180/`), retirer un rôle à un utilisateur ou le désactiver, puis se reconnecter | la décision d'accès vient de Keycloak, pas d'IRIS |
| 7 | Exécuter les trois `curl` du [§4.2](#42-une-api-protégée-par-jeton) | l'API accepte un **jeton** valide, refuse un jeton falsifié et l'absence de jeton |

À dire pendant la démonstration : l'accès par mot de passe (port 80, comptes IRIS existants) **reste volontairement ouvert**
dans cette version de démonstration ; il n'est pas traité ici (voir le [§9](#9-avant-aws--production)).

---

## 5. Gérer les utilisateurs et les rôles

Tout se fait dans Keycloak (console <http://keycloak:8180/>, royaume `iris`) :

- **Créer un utilisateur** : Users > Add user ; Credentials > Set password ; Role mapping > Assign role (`iris-admin`, …).
  Le compte IRIS correspondant apparaît à sa première connexion.
- **Retirer un accès** : désactiver ou supprimer l'utilisateur dans Keycloak. Les jetons déjà émis restent valables jusqu'à
  leur expiration (**5 minutes**), `oauth2-proxy` les rafraîchit toutes les 4 minutes tant que la session Keycloak est valide.
- **Changer les rôles d'un utilisateur** : modifier le *role mapping* dans Keycloak ; pris en compte à la prochaine connexion
  / au prochain rafraîchissement du jeton.
- **Les utilisateurs IRIS créés à la volée** restent dans IRIS après suppression côté Keycloak : les supprimer si besoin
  (Portail > Sécurité > Utilisateurs, ou `##class(Security.Users).Delete(nom)`). Sans jeton valide ils ne peuvent plus se connecter par OAuth2.
- **Ajouter un rôle** : créer le rôle dans Keycloak (Realm roles) **et** le rôle IRIS de même nom
  (dans `adm.oidc.EnsureRoles`, puis relancer `./configure-oidc.sh`).

Le royaume importé impose : 12 caractères minimum, interdiction du nom d'utilisateur comme mot de passe, historique de 3,
blocage temporaire après 5 échecs, jetons d'accès de 5 minutes, session SSO inactive limitée à 30 minutes.

---

## 6. Accès de secours (break-glass)

Si Keycloak ou `oauth2-proxy` est indisponible, **le portail reste joignable avec un mot de passe IRIS** :

- <http://localhost/iris-health-training-dev/csp/sys/UtilHome.csp> (port 80, nginx ne passe pas par `oauth2-proxy`) ;
- les applications web ont conservé l'authentification par mot de passe ;
- la console du conteneur : `docker exec -it iris-health-training-dev iris session IRIS -U %SYS`.

⚠ Ce secours est aussi **la faille restante** : tant que le port 80 est ouvert et que `testuser` (rôle `%All`, mot de passe de démonstration)
existe, la protection par Keycloak est contournable. Voir [§9](#9-avant-aws--production).

---

## 7. Reconstruire l'image IRIS

La configuration est faite **au build** par `iris/iris.script` (fin du script) :

```
zn "COMMON"
do $SYSTEM.OBJ.Import("/home/irisowner/dev/src/adm/oidc.cls", "ck")
do ##class(adm.oidc).Configure()
```

Pour reconstruire : `docker compose -p iris-health-training build iris-dev` puis recréer le conteneur
(commande **non testée** — je n'ai pas relancé de reconstruction complète). Points à connaître :

- Le `Dockerfile` copie `iris/key/iris.key` dans l'image : la clé doit être valide au moment du build.
- Keycloak n'a pas besoin d'être démarré pendant le build : la classe ne le contacte pas.
- Les volumes IRIS sont **durables et externes** : une nouvelle image ne modifie pas la configuration d'un volume qui existe déjà.
  Sur un volume existant, relancer `./configure-oidc.sh` (idempotent).
- Après la reconstruction, refaire les vérifications du [§4](#4-vérifications-de-bout-en-bout).

---

## 8. Dépannage

| Symptôme | Cause | Remède |
|---|---|---|
| `502 Bad Gateway` après la connexion Keycloak ; journal nginx : `upstream sent too big header` | le cookie de session d'`oauth2-proxy` (3 jetons chiffrés) dépasse le tampon nginx de 4 Ko | `proxy_buffer_size 16k` (+ `proxy_buffers`, `proxy_busy_buffers_size`) dans `nginx/tls.conf` : déjà fait |
| `oauth2-proxy` : `Rejecting invalid redirect … not in whitelist` | paramètre `rd` en URL absolue | `error_page 401 =302 /oauth2/start?rd=$request_uri;` (URL relative) : déjà fait |
| `nginx -t` : `host not found in upstream "oauth2-proxy"` | `oauth2-proxy` pas encore démarré | démarrer `oauth2-proxy` avant de recharger nginx |
| Le jeton valide donne la page de connexion IRIS | mapping du resource server absent (créé par script, pas par le portail) | `adm.oidc.EnsureResourceServer` crée le mapping `%Service_WebGateway` / `*` |
| Le portail s'ouvre, mais une page d'administration (Users, Roles…) renvoie la page de connexion | OAuth2 non activé sur **toutes** les applications du portail (`/csp/sys/sec`, `/op`, `/mgr`, `/exp`) | `adm.oidc.WEBAPPS` les contient maintenant ; relancer `./configure-oidc.sh` |
| Jeton rejeté, `iss` inattendu | l'émetteur du jeton ≠ `http://keycloak:8180/realms/iris` | utiliser le **même nom** `keycloak:8180` partout (navigateur, conteneurs, outils ; `--resolve` avec curl) |
| Le sélecteur d'espaces ne propose que `%SYS`, `HSLIB`, `USER` ; *Interoperability* est grisé | session IRIS ouverte avant un changement de rôles, ou espace courant `%SYS` (le menu n'est actif que dans un espace interopérable) | **Logout**, se reconnecter, puis choisir `DGLAB` ou `TRAINING` |
| Une page d'interopérabilité (`EnsPortal.*`) redemande un mot de passe IRIS | cette page n'est pas derrière `oauth2-proxy` | l'emplacement nginx doit couvrir `csp/healthshare/<espace>/EnsPortal.` (déjà fait dans `nginx/tls.conf`) |
| Utilisateur authentifié mais sans droits (`403`) | le jeton n'a pas de revendication `roles` ou de rôle Keycloak | vérifier le mapper `iris-realm-roles` du client et le *role mapping* de l'utilisateur ; décoder le jeton (jwt.io, hors production) |
| `Access Denied` (`ERROR #822`) | jeton falsifié, expiré ou d'une autre audience | obtenir un nouveau jeton ; l'audience doit contenir `iris-api` |
| Keycloak ne démarre pas | `keycloak/secrets.env` manquant ou mal formé | relancer `./keycloak/init-secrets.sh` |

Journaux utiles : `docker logs iris-health-training-keycloak`, `docker logs iris-health-training-oauth2-proxy`,
`docker logs iris-health-training-nginx`, et dans IRIS le journal d'événements de l'espace concerné.

---

## 9. Avant AWS / production

> **Hors périmètre de la démonstration** : les points 4 (port 80) et 5 (comptes `%All`, mots de passe) ci-dessous sont laissés tels quels
> à votre demande. Cette section décrit ce qu'il faudrait faire pour un usage réel.

**Rien de ce document n'a été appliqué sur AWS.** Ne pas pousser `docker-compose.yml` tel quel sur AWS : nginx y monte
`nginx/tls.conf` et `nginx/certs/`, absents là-bas. Liste de ce qui reste à faire :

1. **Vrai certificat TLS** (par exemple Let's Encrypt) à la place du certificat auto-signé, et **HSTS** activé.
2. **Nom public de Keycloak** en HTTPS (par exemple `https://auth.exemple.org`) : `KC_HOSTNAME`, `OAUTH2_PROXY_OIDC_ISSUER_URL`,
   `adm.oidc.ISSUER`, `OAUTH2_PROXY_REDIRECT_URL` et les `redirectUris` du client `iris-portal` doivent tous utiliser ce nom.
3. **Keycloak de production** : `start` (pas `start-dev`), base PostgreSQL (le conteneur `training-postgres` existe), `KC_PROXY_HEADERS`,
   import du royaume sans mot de passe temporaire connu, sauvegarde du royaume.
4. **Fermer ou rediriger le port 80** vers HTTPS : aujourd'hui IRIS accepte aussi le jeton en clair sur le port 80, parce qu'il ne voit
   pas le TLS terminé par nginx.
5. **Comptes IRIS** : retirer `%All` des comptes de démonstration, changer les mots de passe (le mot de passe `_SYSTEM` d'AWS a été
   partagé dans une conversation : à changer), désactiver les comptes inutiles, retirer l'authentification *non authentifiée*
   (bit `Unauthenticated`) des applications `/csp/sys*` si elle n'est pas voulue. **Non traité ici.**
6. **Rejouer la configuration IRIS** sur AWS : `./configure-oidc.sh --target aws --instance dev` (option `--target aws` **non testée**).
7. **Protéger aussi** les services HTTP exposés au public (HL7, FHIR) par jetons, et révoquer les secrets de démonstration.
8. Mettre à jour la licence avant son expiration (30/11/2026) : `./deploy-key.sh`.

---

## 10. Fichiers du dépôt

| Fichier | Rôle |
|---|---|
| `iris/src/adm/oidc.cls` | configuration IRIS idempotente (rôles, serveur OAuth2, resource server, applications web) |
| `iris/iris.script` | appelle `adm.oidc.Configure()` au build de l'image |
| `configure-oidc.sh` | rejoue cette configuration sur un conteneur existant (local ou AWS) |
| `keycloak/realm-iris.json` | royaume `iris` : rôles, clients `iris-portal` / `iris-api` / `iris-service`, utilisateurs de démo |
| `keycloak/init-secrets.sh` | génère `keycloak/secrets.env` (non versionné) |
| `docker-compose.yml` | services `keycloak` et `oauth2-proxy`, ports et montages TLS de nginx |
| `nginx/tls.conf` | HTTPS, en-têtes de sécurité, `/oauth2/*`, protection par `oauth2-proxy` du portail (`/csp/sys`) et des pages d'interopérabilité (`/csp/healthshare/<espace>/EnsPortal.*`) |
| `nginx/make-local-cert.sh` | certificat auto-signé local |
| `.gitignore` | exclut `keycloak/secrets.env`, `nginx/certs/`, `**/*.ISCkey` |

**Ce qui n'est pas testé** : reconstruction complète de l'image, exécution sur AWS, ports et comportement avec un vrai certificat,
connexion depuis un navigateur réel (le parcours navigateur a été simulé en HTTP avec cookies, de bout en bout, avec des utilisateurs jetables
puis avec `iris.viewer`).
