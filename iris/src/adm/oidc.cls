/// Keycloak (OpenID Connect / OAuth 2.0) integration of the IRIS instance.
///
/// Idempotent: can be run at image build time (iris.script) AND on an existing container
/// (configure-oidc.sh), because the durable %SYS volumes keep the configuration of the first start.
/// Nothing here needs Keycloak to be up: the endpoints of the Keycloak server definition are declared
/// explicitly (standard Keycloak paths) instead of being discovered.
///
/// What it configures:
///  1. IRIS roles named like the Keycloak realm roles (iris-admin, iris-developer, iris-operator, iris-viewer),
///     each granting a built-in IRIS role: the roles of a token map to IRIS roles one to one, none is %All.
///  2. The OAuth 2.0 server definition of the Keycloak realm (issuer must equal the "iss" claim of the tokens).
///  3. A resource server (audience iris-api) that validates the JWT locally and maps
///     claim preferred_username -> IRIS user and claim roles -> IRIS roles (SimpleAuthenticator).
///  4. The OAuth2 authentication method on the listed web applications (added to the existing methods, nothing removed).
Class adm.oidc Extends %RegisteredObject
{

/// Issuer of the Keycloak realm. MUST be identical to the "iss" claim of the access tokens, and be
/// reachable from this container and from the browser (see KC_HOSTNAME in docker-compose.yml).
Parameter ISSUER = "http://keycloak:8180/realms/iris";

/// Audience that the access tokens must contain (client iris-api in the realm)
Parameter AUDIENCE = "iris-api";

Parameter RESOURCESERVER = "keycloak-iris-api";

/// Web applications that also accept OAuth2 bearer tokens (comma separated). Password authentication
/// stays enabled on them: it is the break-glass access if Keycloak is down.
/// The Management Portal is made of several web applications: all of them must accept the token,
/// otherwise a page served by /csp/sys/sec (users, roles...) falls back to the login page.
Parameter WEBAPPS = "/csp/healthshare/dglab,/csp/healthshare/training,/csp/sys,/csp/sys/exp,/csp/sys/mgr,/csp/sys/op,/csp/sys/sec";

/// Applies the whole configuration. pWebApps overrides the default list of web applications.
ClassMethod Configure(pWebApps As %String = {..#WEBAPPS}, pVerbose As %Boolean = 1) As %Status
{
	New $Namespace
	Set $Namespace = "%SYS"
	Set tSC = $$$OK
	Try {
		Set tSC = ..EnsureRoles(pVerbose)
		Quit:$$$ISERR(tSC)
		Set tSC = ..EnsureServerDefinition(pVerbose)
		Quit:$$$ISERR(tSC)
		Set tSC = ..EnsureResourceServer(pVerbose)
		Quit:$$$ISERR(tSC)
		Set tSC = ..EnableOAuth2(pWebApps, pVerbose)
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Write:pVerbose "adm.oidc.Configure: ", $Select($$$ISOK(tSC):"OK", 1:$System.Status.GetErrorText(tSC)), !
	Quit tSC
}

/// IRIS roles named like the Keycloak realm roles. Each grants built-in IRIS roles and, for the
/// interoperability ones, roles defined by the training setup (adm.utils / SecurityRoles.xml).
/// A granted role that does not exist yet is skipped with a warning (fresh image): run configure-oidc.sh
/// again once the setup has created it. Existing roles are updated, so the mapping can be changed here.
ClassMethod EnsureRoles(pVerbose As %Boolean = 1) As %Status
{
	Set tSC = $$$OK
	Set tMap("iris-admin") = "%Manager,Interop_Operator_Role"
	Set tMap("iris-developer") = "%Developer"
	Set tMap("iris-operator") = "%Operator"
	Set tMap("iris-viewer") = "Interop_Viewer_Role"
	Set tRole = ""
	For {
		Set tRole = $Order(tMap(tRole))
		Quit:tRole=""

		// keep only the granted roles that exist
		Set tGrant = "", tSkipped = ""
		For i = 1:1:$Length(tMap(tRole), ",") {
			Set tG = $Piece(tMap(tRole), ",", i)
			If ##class(Security.Roles).Exists(tG) { Set tGrant = tGrant _ $Select(tGrant="":"", 1:",") _ tG } Else { Set tSkipped = tSkipped _ $Select(tSkipped="":"", 1:",") _ tG }
		}
		Write:pVerbose&&(tSkipped'="") "  WARNING role ", tRole, ": granted role(s) not found, skipped: ", tSkipped, !

		If ##class(Security.Roles).Exists(tRole) {
			Kill tProps
			Set tSC = ##class(Security.Roles).Get(tRole, .tProps)
			Quit:$$$ISERR(tSC)
			If $Get(tProps("GrantedRoles")) = tGrant {
				Write:pVerbose "  role ", tRole, " already up to date (", tGrant, ")", !
				Continue
			}
			Set tProps("GrantedRoles") = tGrant
			Set tSC = ##class(Security.Roles).Modify(tRole, .tProps)
			Write:pVerbose "  role ", tRole, " -> ", tGrant, ": ", $Select($$$ISOK(tSC):"updated", 1:$System.Status.GetErrorText(tSC)), !
		} Else {
			Set tSC = ##class(Security.Roles).Create(tRole, "Keycloak realm role " _ tRole, "", tGrant)
			Write:pVerbose "  role ", tRole, " -> ", tGrant, ": ", $Select($$$ISOK(tSC):"created", 1:$System.Status.GetErrorText(tSC)), !
		}
		Quit:$$$ISERR(tSC)
	}
	Quit tSC
}

/// Id of the server definition whose issuer is pIssuer ("" if none)
ClassMethod FindServerDefinition(pIssuer As %String) As %String [ Private ]
{
	Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM OAuth2.ServerDefinition WHERE IssuerEndpoint = ?", pIssuer)
	Quit $Select(tRS.%Next():tRS.%Get("ID"), 1:"")
}

/// OAuth 2.0 server definition of the Keycloak realm, with explicit endpoints (no discovery)
ClassMethod EnsureServerDefinition(pVerbose As %Boolean = 1) As %Status
{
	Set tIssuer = ..#ISSUER
	Set tOIDC = tIssuer _ "/protocol/openid-connect"
	Set tId = ..FindServerDefinition(tIssuer)
	Set tServer = $Select(tId'="":##class(OAuth2.ServerDefinition).%OpenId(tId), 1:"")
	Set tNew = '$IsObject(tServer)
	Set:tNew tServer = ##class(OAuth2.ServerDefinition).%New()
	Set tServer.IssuerEndpoint = tIssuer
	Set tServer.IsDiscovery = 0
	Set tServer.AuthorizationEndpoint = tOIDC _ "/auth"
	Set tServer.TokenEndpoint = tOIDC _ "/token"
	Set tServer.UserinfoEndpoint = tOIDC _ "/userinfo"
	Set tServer.IntrospectionEndpoint = tOIDC _ "/token/introspect"
	Set tServer.RevocationEndpoint = tOIDC _ "/revoke"
	Set tMeta = ##class(OAuth2.Server.Metadata).%New()
	Set tMeta.issuer = tIssuer
	Set tMeta."authorization_endpoint" = tServer.AuthorizationEndpoint
	Set tMeta."token_endpoint" = tServer.TokenEndpoint
	Set tMeta."userinfo_endpoint" = tServer.UserinfoEndpoint
	Set tMeta."introspection_endpoint" = tServer.IntrospectionEndpoint
	Set tMeta."revocation_endpoint" = tServer.RevocationEndpoint
	Set tMeta."jwks_uri" = tOIDC _ "/certs"
	Set tServer.Metadata = tMeta
	Set tSC = tServer.%Save()
	Write:pVerbose "  server definition ", tIssuer, ": ", $Select($$$ISOK(tSC):$Select(tNew:"created", 1:"updated"), 1:$System.Status.GetErrorText(tSC)), !
	Quit tSC
}

/// Resource server: local JWT validation, user = preferred_username, roles = roles claim
ClassMethod EnsureResourceServer(pVerbose As %Boolean = 1) As %Status
{
	Set tName = ..#RESOURCESERVER
	Set tId = ..FindServerDefinition(..#ISSUER)
	Set tServer = $Select(tId'="":##class(OAuth2.ServerDefinition).%OpenId(tId), 1:"")
	If '$IsObject(tServer) Quit $$$ERROR($$$GeneralError, "Server definition " _ ..#ISSUER _ " is missing")
	Set tRS = ##class(OAuth2.ResourceServer).%OpenId(tName)
	Set tNew = '$IsObject(tRS)
	Set:tNew tRS = ##class(OAuth2.ResourceServer).%New()
	Set tRS.Name = tName
	Set tRS.Enabled = 1
	Set tRS.Description = "Access tokens issued by the Keycloak realm iris (audience " _ ..#AUDIENCE _ ")"
	Set tRS.ServerDefinition = tServer
	Set tRS.Audiences = $ListBuild(..#AUDIENCE)
	Set tRS.AccessTokenIsJWT = 1
	Set tRS.AlwaysCallIntrospection = 0
	Set tRS.UseOIDC = 0
	Set tRS.Authenticator = ##class(%OAuth2.ResourceServer.SimpleAuthenticator).%New({"UserClaim":"preferred_username", "RoleClaim":"roles"})
	Set tSC = tRS.%Save()
	Write:pVerbose "  resource server ", tName, ": ", $Select($$$ISOK(tSC):$Select(tNew:"created", 1:"updated"), 1:$System.Status.GetErrorText(tSC)), !
	Quit:$$$ISERR(tSC) tSC

	// Resource mapping: the portal creates it for the first resource server; a scripted one needs it explicitly.
	// Service = the service carrying the requests, Key = web application ("*" = all of them).
	Set tRS2 = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM OAuth2_ResourceServer.Mapping WHERE Service = ? AND ""Key"" = ?", "%Service_WebGateway", "*")
	If 'tRS2.%Next() {
		Set tMap = ##class(OAuth2.ResourceServer.Mapping).%New()
		Set tMap.Service = "%Service_WebGateway"
		Set tMap.Key = "*"
		Set tMap.Resource = tRS
		Set tMap.ResourceName = tName
		Set tSC = tMap.%Save()
		Write:pVerbose "  resource mapping %Service_WebGateway / *: ", $Select($$$ISOK(tSC):"created", 1:$System.Status.GetErrorText(tSC)), !
	}
	Quit tSC
}

/// Adds the OAuth2 method to the authentication methods of each web application (and of the
/// WebGateway service, which transports the bearer token). Existing methods are kept.
ClassMethod EnableOAuth2(pWebApps As %String, pVerbose As %Boolean = 1) As %Status
{
	Set tOAuth2 = ##class(%SYSTEM.Security.Datatype.Authentication).DisplayToLogical("OAuth2")

	// Service used by the Web Gateway
	Set tSC = ##class(Security.Services).Get("%Service_WebGateway", .tSvc)
	If $$$ISOK(tSC), '$ZBoolean(+$Get(tSvc("AutheEnabled")), tOAuth2, 1) {
		Set tSvc("AutheEnabled") = $ZBoolean(+tSvc("AutheEnabled"), tOAuth2, 7)
		Set tSC = ##class(Security.Services).Modify("%Service_WebGateway", .tSvc)
		Write:pVerbose "  service %Service_WebGateway: ", $Select($$$ISOK(tSC):"OAuth2 enabled", 1:$System.Status.GetErrorText(tSC)), !
	}

	For i = 1:1:$Length(pWebApps, ",") {
		Set tApp = $ZStrip($Piece(pWebApps, ",", i), "<>W")
		Continue:tApp=""
		Kill tProps
		If '##class(Security.Applications).Exists(tApp) {
			Write:pVerbose "  web app ", tApp, " does not exist here: skipped", !
			Continue
		}
		Set tSC = ##class(Security.Applications).Get(tApp, .tProps)
		Quit:$$$ISERR(tSC)
		If $ZBoolean(+tProps("AutheEnabled"), tOAuth2, 1) {
			Write:pVerbose "  web app ", tApp, ": OAuth2 already enabled", !
			Continue
		}
		Set tProps("AutheEnabled") = $ZBoolean(+tProps("AutheEnabled"), tOAuth2, 7)
		Set tSC = ##class(Security.Applications).Modify(tApp, .tProps)
		Write:pVerbose "  web app ", tApp, ": ", $Select($$$ISOK(tSC):"OAuth2 enabled", 1:$System.Status.GetErrorText(tSC)), !
		Quit:$$$ISERR(tSC)
	}
	Quit tSC
}

}
