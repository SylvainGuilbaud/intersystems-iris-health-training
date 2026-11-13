/// Native LDAP authentication and authorization of the IRIS instance (demo OpenLDAP, docker-compose.yml, service "ldap").
///
/// Idempotent: can be replayed on an existing container with configure-ldap.sh. It is NOT called by iris.script: the
/// password of the account that searches the directory is a secret, which must not be baked in the image (it is
/// passed at run time from ldap/secrets.env).
///
/// What it configures:
///  1. an LDAP configuration named like the LDAP domain (users log in as "ldap.admin" or "ldap.admin@example.org"),
///     with the universal authorization groups enabled: a user that belongs to the LDAP group
///     "intersystems-Role-iris-admin" gets the IRIS role "iris-admin" (the same roles as the Keycloak users);
///  2. that domain as the default security domain of the instance;
///  3. the LDAP authentication method on the listed web applications (added to the existing methods, none is removed).
Class adm.ldap Extends %RegisteredObject
{

/// LDAP domain = name of the LDAP configuration
Parameter DOMAIN = "example.org";

/// LDAP server(s), host:port, separated by spaces. "ldap" is the Docker network name of the demo server.
Parameter HOSTS = "ldap:389";

/// Base of the user search. IRIS APPENDS this base to the name of the search account (SEARCHUSER) to build the DN
/// it binds with: both must be chosen together (here "cn=readonly" + "dc=example,dc=org" = the readonly account).
Parameter BASEDN = "dc=example,dc=org";

Parameter GROUPSDN = "ou=groups,dc=example,dc=org";

/// Account allowed to search users and groups, RELATIVE to BASEDN (IRIS appends the base DN: giving the full DN here
/// makes IRIS bind as "cn=readonly,dc=example,dc=org,<base>", a DN that does not exist, and the bind fails with error 49)
Parameter SEARCHUSER = "cn=readonly";

/// Attribute that holds the login name (Active Directory: sAMAccountName)
Parameter LOGINATTRIBUTE = "uid";

/// Web applications that also accept LDAP authentication (comma separated). Password authentication stays enabled
/// on them: it is the break-glass access if the directory is down.
Parameter WEBAPPS = "/csp/sys,/csp/sys/exp,/csp/sys/mgr,/csp/sys/op,/csp/sys/sec";

/// LDAPFlags bits: UseGroups 8 + UseUniversalGroups 32 + Enabled 64
Parameter FLAGS = 104;

/// Applies the whole configuration. pSearchPassword is the password of Parameter SEARCHUSER.
ClassMethod Configure(pSearchPassword As %String, pWebApps As %String = {..#WEBAPPS}, pVerbose As %Boolean = 1, pHosts As %String = {..#HOSTS}) As %Status
{
	New $Namespace
	Set $Namespace = "%SYS"
	Set tSC = $$$OK
	Try {
		Set tSC = ..EnsureConfiguration(pSearchPassword, pHosts, pVerbose)
		Quit:$$$ISERR(tSC)
		Set tSC = ..EnsureDefaultDomain(pVerbose)
		Quit:$$$ISERR(tSC)
		Set tSC = ..EnableLDAP(pWebApps, pVerbose)
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Write:pVerbose "adm.ldap.Configure: ", $Select($$$ISOK(tSC):"OK", 1:$System.Status.GetErrorText(tSC)), !
	Quit tSC
}

/// The LDAP configuration (named like the domain)
ClassMethod EnsureConfiguration(pSearchPassword As %String, pHosts As %String, pVerbose As %Boolean = 1) As %Status
{
	If pSearchPassword = "" Quit $$$ERROR($$$GeneralError, "The password of the LDAP search account is required")
	Set tName = ..#DOMAIN
	Set tProps("LDAPHostNames") = pHosts
	Set tProps("LDAPBaseDN") = ..#BASEDN
	Set tProps("LDAPBaseDNForGroups") = ..#GROUPSDN
	Set tProps("LDAPSearchUsername") = ..#SEARCHUSER
	Set tProps("LDAPSearchPassword") = pSearchPassword
	Set tProps("LDAPUniqueDNIdentifier") = ..#LOGINATTRIBUTE
	Set tProps("LDAPDomainName") = ..#DOMAIN
	Set tProps("LDAPFlags") = ..#FLAGS
	Set tProps("LDAPAttributeFullName") = "displayName"
	Set tProps("LDAPAttributeMail") = "mail"
	If ##class(Security.LDAPConfigs).Exists(tName) {
		Set tSC = ##class(Security.LDAPConfigs).Modify(tName, .tProps)
		Write:pVerbose "  LDAP configuration ", tName, ": ", $Select($$$ISOK(tSC):"updated", 1:$System.Status.GetErrorText(tSC)), !
	} Else {
		Set tSC = ##class(Security.LDAPConfigs).Create(tName, .tProps)
		Write:pVerbose "  LDAP configuration ", tName, ": ", $Select($$$ISOK(tSC):"created", 1:$System.Status.GetErrorText(tSC)), !
	}
	Quit tSC
}

/// The LDAP domain becomes the default security domain, so that "ldap.admin" means "ldap.admin@example.org"
ClassMethod EnsureDefaultDomain(pVerbose As %Boolean = 1) As %Status
{
	Set tSC = ##class(Security.System).Get("SYSTEM", .tProps)
	Quit:$$$ISERR(tSC) tSC
	If $Get(tProps("DefaultSecurityDomain")) = ..#DOMAIN {
		Write:pVerbose "  default security domain already ", ..#DOMAIN, !
		Quit $$$OK
	}
	Write:pVerbose "  default security domain: ", $Get(tProps("DefaultSecurityDomain")), " -> ", ..#DOMAIN, !
	Set tProps("DefaultSecurityDomain") = ..#DOMAIN
	Set tSC = ##class(Security.System).Modify("SYSTEM", .tProps)
	Quit tSC
}

/// LDAP method on the instance (kept if already there) and on the web applications
ClassMethod EnableLDAP(pWebApps As %String, pVerbose As %Boolean = 1) As %Status
{
	Set tLDAP = ##class(%SYSTEM.Security.Datatype.Authentication).DisplayToLogical("LDAP")
	Set tSC = ##class(Security.System).Get("SYSTEM", .tSys)
	Quit:$$$ISERR(tSC) tSC
	If '$ZBoolean(+tSys("AutheEnabled"), tLDAP, 1) {
		Set tSys("AutheEnabled") = $ZBoolean(+tSys("AutheEnabled"), tLDAP, 7)
		Set tSC = ##class(Security.System).Modify("SYSTEM", .tSys)
		Write:pVerbose "  instance: LDAP authentication ", $Select($$$ISOK(tSC):"allowed", 1:$System.Status.GetErrorText(tSC)), !
		Quit:$$$ISERR(tSC) tSC
	} Else {
		Write:pVerbose "  instance: LDAP authentication already allowed", !
	}

	// The service used by the Web Gateway must allow the method too, otherwise the setting of the web applications has no effect.
	Set tSC = ##class(Security.Services).Get("%Service_WebGateway", .tSvc)
	Quit:$$$ISERR(tSC) tSC
	If $ZBoolean(+tSvc("AutheEnabled"), tLDAP, 1) {
		Write:pVerbose "  service %Service_WebGateway: LDAP already enabled", !
	} Else {
		Set tSvc("AutheEnabled") = $ZBoolean(+tSvc("AutheEnabled"), tLDAP, 7)
		Set tSC = ##class(Security.Services).Modify("%Service_WebGateway", .tSvc)
		Write:pVerbose "  service %Service_WebGateway: ", $Select($$$ISOK(tSC):"LDAP enabled", 1:$System.Status.GetErrorText(tSC)), !
		Quit:$$$ISERR(tSC) tSC
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
		If $ZBoolean(+tProps("AutheEnabled"), tLDAP, 1) {
			Write:pVerbose "  web app ", tApp, ": LDAP already enabled", !
			Continue
		}
		Set tProps("AutheEnabled") = $ZBoolean(+tProps("AutheEnabled"), tLDAP, 7)
		Set tSC = ##class(Security.Applications).Modify(tApp, .tProps)
		Write:pVerbose "  web app ", tApp, ": ", $Select($$$ISOK(tSC):"LDAP enabled", 1:$System.Status.GetErrorText(tSC)), !
		Quit:$$$ISERR(tSC)
	}
	Quit tSC
}

}
