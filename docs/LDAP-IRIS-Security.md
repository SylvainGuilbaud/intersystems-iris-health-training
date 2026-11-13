# Authentification LDAP native du portail IRIS

Procédure pas à pas pour authentifier des utilisateurs contre un annuaire LDAP et leur donner leurs rôles IRIS à partir de leurs groupes LDAP.
Tout ce qui est décrit a été exécuté et testé **en local** (conteneur `iris-health-training-dev`, IRIS for Health 2026.1), puis déployé sur **AWS** ([§ AWS](#aws)).

- [1. Ce que l'on met en place](#1-ce-que-lon-met-en-place)
- [2. Étapes](#2-étapes)
- [3. Vérifier](#3-vérifier)
- [4. Gérer les utilisateurs et les groupes](#4-gérer-les-utilisateurs-et-les-groupes)
- [5. Les pièges rencontrés](#5-les-pièges-rencontrés)
- [AWS](#aws)
- [6. Limites et suite](#6-limites-et-suite)
- [7. Fichiers du dépôt](#7-fichiers-du-dépôt)

---

## 1. Ce que l'on met en place

```
 Navigateur / outil  --(identifiant + mot de passe LDAP)-->  IRIS (portail /csp/sys, port 80)
                                                                |
                                          1. recherche l'utilisateur   (uid=<identifiant>, compte « readonly »)
                                          2. vérifie son mot de passe  (liaison avec le DN de l'utilisateur)
                                          3. lit son attribut memberOf (ses groupes)
                                                                v
                                                   OpenLDAP de démonstration (conteneur « ldap », réseau Docker uniquement)
```

C'est la méthode **LDAP native d'IRIS** : IRIS interroge lui-même l'annuaire, sans passer par Keycloak. Le portail en HTTPS (`https://localhost/…`) reste, lui, derrière la
connexion Keycloak ([Keycloak-IRIS-Security.md](Keycloak-IRIS-Security.md)) ; la connexion LDAP est celle du portail IRIS sur le **port 80**.

**Rôles.** Les groupes LDAP suivent la convention *groupes d'autorisation universels* d'InterSystems : un utilisateur membre du groupe `intersystems-Role-iris-admin`
reçoit le rôle IRIS `iris-admin`. Ce sont les **mêmes quatre rôles** que pour les utilisateurs Keycloak :

| Utilisateur LDAP | Groupe LDAP | Rôle IRIS obtenu | Rôles IRIS accordés (voir `adm.oidc`) |
|---|---|---|---|
| `ldap.admin` | `intersystems-Role-iris-admin` | `iris-admin` | `%Manager`, `Interop_Operator_Role` |
| `ldap.developer` | `intersystems-Role-iris-developer` | `iris-developer` | `%Developer` |
| `ldap.operator` | `intersystems-Role-iris-operator` | `iris-operator` | `%Operator` |
| `ldap.viewer` | `intersystems-Role-iris-viewer` | `iris-viewer` | `Interop_Viewer_Role` |

Les rôles `iris-*` sont créés par `adm.oidc` (configuration Keycloak ; `iris.script` l'exécute juste avant `adm.ldap`) : sur une instance existante, **exécutez d'abord `./configure-oidc.sh`**, ou créez ces rôles autrement, car l'autorisation LDAP ne crée pas de rôle IRIS.

---

## 2. Étapes

> Les blocs `bash` se collent tels quels dans zsh ou bash (aucun commentaire en fin de ligne).

### Étape 1 — Générer les secrets et les utilisateurs de démo (une seule fois)

```bash
./ldap/init-secrets.sh
```

Crée `ldap/secrets.env` (mode 600, ignoré par git : mots de passe de l'administrateur, de la configuration, du compte de lecture et des utilisateurs de démo)
et `ldap/bootstrap/50-iris-demo.ldif` (4 utilisateurs, 4 groupes, mots de passe hachés en SSHA ; ignoré par git).
Il crée aussi `ldap/.env`, un lien vers `secrets.env` que lit `ldap/test-ldap.http`.

### Étape 2 — Démarrer le serveur LDAP

```bash
docker compose -p iris-health-training up -d --no-deps ldap
```

Le LDIF est chargé au **premier** démarrage (répertoire de données vide). Le port 389 n'est **pas** publié sur l'hôte : le serveur n'est joignable que depuis le réseau Docker.

### Étape 3 — Configurer IRIS, en deux temps

```bash
./configure-ldap.sh --target local --instance dev --apps none
```

Crée la configuration LDAP `example.org` et fait de ce domaine le domaine de sécurité par défaut de l'instance. **Aucune application web n'est modifiée** : c'est le temps de vérifier que
l'accès de secours (`testuser`) fonctionne toujours. Le script demande un utilisateur et un mot de passe IRIS (ou `IRIS_LOGIN_USER` / `IRIS_LOGIN_PASSWORD`).

```bash
./configure-ldap.sh --target local --instance dev --apps default
```

Active en plus la méthode LDAP sur le service `%Service_WebGateway` et sur les applications web du portail (`/csp/sys`, `/exp`, `/mgr`, `/op`, `/sec`). Le mot de passe y reste actif.
Les deux commandes sont **idempotentes**. Le mot de passe du compte de recherche est lu dans `ldap/secrets.env` et transmis à IRIS à l'exécution : il n'est ni dans l'image ni dans le dépôt.

---

## 3. Vérifier

Ouvrez [`ldap/test-ldap.http`](../ldap/test-ldap.http) dans VS Code (extension REST Client) et cliquez sur **Send Request**. Résultats attendus, observés :

| # | Requête | Résultat |
|---|---|---|
| 1 | `ldap.admin`, page d'accueil du portail | **200**, « IRIS - Home », utilisateur `ldap.admin` |
| 2 | `ldap.admin`, page « Users » (administration de la sécurité) | **200**, « Users » : le rôle `iris-admin` vient du groupe LDAP |
| 3 | `ldap.viewer`, même page | **403** : authentifié, mais seulement `iris-viewer` |
| 4 | `ldap.developer`, même page | **403** |
| 5 | `ldap.admin` avec un mauvais mot de passe | page « Login IRIS » (la liaison LDAP est refusée) |
| 6 | utilisateur absent de l'annuaire | page « Login IRIS » |

Dans le navigateur : ouvrez <http://localhost/iris-health-training-dev/csp/sys/UtilHome.csp>, saisissez `ldap.admin` (ou `ldap.admin@example.org`) et le mot de passe `LDAP_DEMO_USER_PASSWORD` de
`ldap/secrets.env`. *(Le formulaire de connexion lui-même n'a pas été essayé dans un navigateur ; l'authentification Basic a été testée.)*
Le compte IRIS correspondant est créé à la première connexion, avec son nom complet (`displayName`) et ses rôles ; il apparaît dans *Sécurité > Utilisateurs*.

Pour regarder ce que fait IRIS (terminal, optionnel) :

```bash
docker logs --since 1m iris-health-training-ldap
```

On y voit la liaison du compte `cn=readonly`, la recherche `(uid=ldap.admin)` avec l'attribut `memberOf`, puis la liaison de l'utilisateur. Et dans IRIS, l'audit (`%SYS.Audit`, événement `LoginFailure`)
donne la raison exacte des refus (par exemple « LDAP search bind failed, error 49 »).

---

## 4. Gérer les utilisateurs et les groupes

Le serveur de démonstration est administrable avec les outils OpenLDAP **dans son conteneur**, ou avec l'interface web optionnelle décrite plus bas. Avec le mot de passe `LDAP_ADMIN_PASSWORD` de `ldap/secrets.env` :

```bash
set -a; . ldap/secrets.env; set +a
docker exec -e W="$LDAP_ADMIN_PASSWORD" iris-health-training-ldap sh -c 'ldapsearch -x -H ldap://localhost -D cn=admin,dc=example,dc=org -w "$W" -b dc=example,dc=org "(objectClass=inetOrgPerson)" uid memberOf'
```

- **Ajouter un utilisateur** : une entrée `inetOrgPerson` sous `ou=people,dc=example,dc=org` (attributs `uid`, `cn`, `sn`, `displayName`, `mail`, `userPassword`), avec `ldapadd`.
- **Lui donner un rôle** : l'ajouter comme `uniqueMember` d'un groupe `cn=intersystems-Role-<rôle IRIS>,ou=groups,…`. Le rôle IRIS du même nom doit exister.
- **Retirer un accès** : le supprimer du groupe, ou supprimer l'utilisateur. Les rôles sont relus à chaque ouverture de session IRIS ; une session déjà ouverte garde les anciens rôles jusqu'à sa fermeture.

### Interface web optionnelle : phpLDAPadmin

Le serveur n'a pas d'interface web par défaut. Le service `phpldapadmin` (image `osixia/phpldapadmin`) est **optionnel** : il appartient au profil Compose `ldap-admin` et ne démarre que sur demande.
Son port n'est lié qu'à `127.0.0.1` : il n'est jamais joignable depuis le réseau.

```bash
docker compose -p iris-health-training --profile ldap-admin up -d --no-deps phpldapadmin
```

Ouvrez <http://127.0.0.1:6480/>, cliquez sur **login** et saisissez :

| Champ | Valeur |
|---|---|
| Login DN | `cn=admin,dc=example,dc=org` |
| Mot de passe | `LDAP_ADMIN_PASSWORD` de `ldap/secrets.env` |

Vous pouvez alors créer un utilisateur, l'ajouter à un groupe `intersystems-Role-…` (attribut `uniqueMember`), changer un mot de passe ou supprimer une entrée. Pour l'arrêter :

```bash
docker compose -p iris-health-training --profile ldap-admin stop phpldapadmin
```

Vérifié en local : la page s'affiche, la connexion avec le mot de passe administrateur réussit et un mauvais mot de passe est refusé. L'interface graphique elle-même n'a pas été parcourue dans un navigateur.
Il n'est **pas** prévu sur AWS : il n'est défini que dans le `docker-compose.yml` local, pas dans `docker-compose.aws-keycloak.yml`. Sur AWS, l'annuaire s'administre avec les outils en ligne de commande décrits ci-dessus.

Plusieurs rôles : plusieurs groupes. Un utilisateur d'un groupe `intersystems-Role-X` dont le rôle `X` n'existe pas dans IRIS n'obtient rien.

---

## 5. Les pièges rencontrés

| Symptôme | Cause | Remède |
|---|---|---|
| Aucun utilisateur LDAP ne se connecte (page « Login IRIS »), alors que l'application a la méthode LDAP | le service **`%Service_WebGateway`** n'avait pas la méthode LDAP (il l'autorisait, sans l'avoir activée) | `adm.ldap` l'active (comme pour OAuth2) |
| Audit : **« LDAP search bind failed, error 49, Invalid credentials »**, alors que le compte de recherche fonctionne avec `ldapsearch` | IRIS **ajoute la base DN** au nom du compte de recherche : avec `cn=readonly,dc=example,dc=org` et la base `ou=people,dc=example,dc=org` il lie `cn=readonly,dc=example,dc=org,ou=people,dc=example,dc=org`, qui n'existe pas | nom **relatif** `cn=readonly` et base `dc=example,dc=org` (`adm.ldap`, paramètres `SEARCHUSER` et `BASEDN`) ; le journal du serveur LDAP (`BIND dn=…`) montre le DN réellement utilisé |
| Connexion réussie, compte IRIS créé, mais **aucun rôle** (403 partout) | IRIS lit les groupes dans l'attribut **`memberOf`** de l'utilisateur ; l'overlay `memberof` d'OpenLDAP ne le renseigne que pour les groupes `groupOfUniqueNames` / `uniqueMember` dans cette image, pas pour `groupOfNames` / `member` | groupes en `groupOfUniqueNames` avec `uniqueMember` (`ldap/init-secrets.sh`) |
| Active Directory à la place d'OpenLDAP | l'identifiant de connexion est `sAMAccountName` et le drapeau `ActiveDirectory` doit être posé | adapter `LOGINATTRIBUTE` et `FLAGS` dans `adm.ldap` (`FLAGS`: UseGroups 8 + UseUniversalGroups 32 + Enabled 64 = 104 ; ActiveDirectory = 1) |

---

## AWS

Déployé par l'étape `ldap` de `./deploy-keycloak-aws.sh` (`./deploy-keycloak-aws.sh ldap`, avec `--dry-run` possible). Elle :

1. génère **sur l'hôte** `ldap/secrets.env` et le LDIF de démo (les mots de passe ne quittent pas la machine) ;
2. démarre le service `ldap` du fichier de surcharge `docker-compose.aws-keycloak.yml` (aucun port publié) ;
3. configure IRIS (`./configure-ldap.sh --target aws --instance dev`) en deux temps : configuration et domaine **sans toucher aux applications**, **contrôle de l'accès de secours** par mot de passe
   (`http/.env`, `IRIS_AWS_*`), puis activation sur le portail. Si l'accès de secours ne répond plus, le script s'arrête avant d'activer LDAP sur les applications.

Vérifié sur AWS (depuis l'hôte, port 80) : les six cas du tableau du §3 donnent les mêmes résultats qu'en local, avec les rôles `iris-admin`, `iris-developer`, `iris-operator`, `iris-viewer`.
Vérifiés aussi après le déploiement : l'API par jeton Keycloak, le parcours du portail en HTTPS via Keycloak, et l'accès de secours par mot de passe.
Sur AWS l'authentification LDAP n'était pas autorisée au niveau de l'instance : `adm.ldap` l'a activée.

Mot de passe des utilisateurs LDAP de démo d'AWS (`ldap.admin`, `ldap.developer`, `ldap.operator`, `ldap.viewer`), à lire sur l'hôte :

```bash
source cloudenv
ssh -i "$ACCESS_KEY_FILENAME" "$CLOUD_USERNAME@$PUBLIC_DNS" "grep LDAP_DEMO_USER_PASSWORD intersystems-iris-health-training/ldap/secrets.env"
```

Connexion : <http://ec2-63-177-72-122.eu-central-1.compute.amazonaws.com/iris-health-training-dev/csp/sys/UtilHome.csp> (**port 80**, comme en local ; sur AWS le portail en HTTPS est derrière Keycloak).

> **Attention : le mot de passe LDAP circule en clair.** Le port 80 d'AWS n'est pas chiffré (le certificat HTTPS est auto-signé et la connexion LDAP du portail n'y passe pas). Un utilisateur LDAP qui se connecte
> sur ce port envoie son mot de passe en clair sur Internet. C'est acceptable pour des comptes de démonstration, pas pour de vrais comptes. Le test `ldap/test-ldap.http` ne vise que le local ;
> le même test sur AWS se fait avec les mêmes requêtes, après avoir remplacé `@iris` par l'adresse d'AWS et le mot de passe par celui de l'hôte (non fait).

---

## 6. Limites et suite

- **Instance `prod` d'AWS** : non configurée (comme pour Keycloak).
- **Pas de TLS.** L'échange IRIS ↔ LDAP circule en clair sur le réseau Docker interne (démo). Pour un vrai annuaire : LDAPS (drapeau `TLSConnection` et certificat de l'autorité).
- **Dans l'image, sans le secret.** `iris.script` appelle `adm.ldap.Configure("")` à la fin du build : la **structure** est posée (configuration LDAP, domaine par défaut, méthode LDAP sur le service et sur le
  portail), mais **sans le mot de passe du compte de recherche**, qui est un secret et qui apparaîtrait dans les couches de l'image s'il y était (argument de build). Tant que ce mot de passe n'est pas envoyé,
  les connexions LDAP échouent (les connexions par mot de passe IRIS ne sont pas touchées) : après un build ou sur un volume neuf, lancer `./configure-ldap.sh`. Un appel suivant avec un mot de passe vide
  **conserve** le mot de passe déjà stocké. Un volume IRIS existant garde sa configuration : le build ne la modifie pas, `configure-ldap.sh` oui. La reconstruction complète de l'image n'a **pas** été exécutée ;
  les lignes d'`iris.script` ont été jouées telles quelles sur l'instance locale.
- **Domaine par défaut.** La configuration fait d'`example.org` le domaine de sécurité par défaut de l'instance (`DefaultSecurityDomain`, auparavant `unknowndomain.com`). Les comptes IRIS locaux
  (`testuser`, `_SYSTEM`…) continuent de se connecter, vérifié ; un identifiant sans domaine peut maintenant aussi être cherché dans l'annuaire.
- **Applications concernées.** La méthode LDAP n'est activée que sur le portail (`/csp/sys*`). Pas sur les applications de l'interopérabilité (`/csp/healthshare/<espace>`) ni sur l'API HL7 : pour les
  authentifier par LDAP, ajouter ces chemins dans `adm.ldap.WEBAPPS` et relancer le script (non essayé).
- **Une autre architecture est possible** : fédérer l'annuaire à Keycloak (*User Federation*), pour que les utilisateurs LDAP passent aussi par la connexion unique et les jetons. Non réalisé ici.

---

## 7. Fichiers du dépôt

| Fichier | Rôle |
|---|---|
| `docker-compose.yml` (service `ldap`) | serveur OpenLDAP de démonstration (`osixia/openldap:1.5.0`, `arm64` et `amd64`), sans port publié |
| `docker-compose.yml` (service `phpldapadmin`) | interface web d'administration, optionnelle (profil `ldap-admin`), liée à `127.0.0.1:6480` |
| `ldap/init-secrets.sh` | génère `ldap/secrets.env`, `ldap/.env` et le LDIF de démo (utilisateurs et groupes) |
| `iris/src/adm/ldap.cls` | configuration IRIS idempotente : configuration LDAP, domaine par défaut, méthode LDAP sur le service et les applications |
| `configure-ldap.sh` | exécute cette configuration sur un conteneur existant (`--apps none` puis `--apps default`) |
| `ldap/test-ldap.http` | six requêtes de test (REST Client) |
| `.gitignore` | exclut `ldap/secrets.env`, `ldap/.env`, `ldap/bootstrap/`, `ldap/data/`, `ldap/slapd.d/` |
