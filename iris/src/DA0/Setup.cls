Include %occInclude

/// Installation de la sécurité pour la page DA.UI.ProductionConfigOperator.
///
/// Principe de délégation de privilège :
///  - L'opérateur reçoit uniquement la ressource %DA_ProductionOperator (ouvrir la page).
///  - Il NE possède PAS %Ens_ProductionConfig.
///  - L'application web qui héberge la page accorde %Ens_ProductionConfig à
///    tous ses utilisateurs (rôle applicatif). Comme cette application ne sert
///    que la page restreinte, l'opérateur ne peut modifier que Enabled/Comment/Category.
///
/// Exécuter depuis n'importe quel namespace :
///   Do ##class(DA.Setup).Install()
///   Do ##class(DA.Setup).Install("FOCH","/csp/foch/operator")
Class DA.Setup Extends %RegisteredObject
{

ClassMethod Install(pNamespace As %String = "FOCH", pWebApp As %String = "/csp/foch/operator") As %Status
{
	New $NAMESPACE
	Set $NAMESPACE = "%SYS"
	Set tSC = $$$OK

	// 1) Ressource d'accès à la page
	If '##class(Security.Resources).Exists("%DA_ProductionOperator") {
		Set tSC = ##class(Security.Resources).Create("%DA_ProductionOperator", "Acces page operateur reglages restreints (Enabled/Comment/Category)", "")
		If $$$ISERR(tSC) Quit tSC
		Write "Ressource %DA_ProductionOperator creee.", !
	}

	// 2) Role operateur restreint
	//    Ressources minimales : ouvrir la page + acces portail + demarrer/arreter la prod.
	//    NB : PAS de %Ens_ProductionConfig ici (fourni par l'application web).
	Set tResList = "%DA_ProductionOperator:U,%Ens_Portal:U,%Ens_Production:U"
	If '##class(Security.Roles).Exists("interop_operator_Role") {
		Set tSC = ##class(Security.Roles).Create("interop_operator_Role", "Operateur interoperabilite restreint", tResList)
		If $$$ISERR(tSC) Quit tSC
		Write "Role interop_operator_Role cree.", !
	}
	Else {
		Set tSC = ##class(Security.Roles).AddResources("interop_operator_Role", tResList)
		If $$$ISERR(tSC) Quit tSC
		Write "Role interop_operator_Role mis a jour.", !
	}

	// 3) Application web dediee, avec escalade vers %Ens_ProductionConfig
	//    MatchRoles=":%Ens_ProductionConfig" => accorde ce role a TOUT utilisateur de l'app.
	If '##class(Security.Applications).Exists(pWebApp) {
		Kill tProps
		Set tProps("NameSpace") = pNamespace
		Set tProps("Description") = "Page operateur reglages restreints (Enabled/Comment/Category)"
		Set tProps("Resource") = "%DA_ProductionOperator"
		Set tProps("MatchRoles") = ":%Ens_ProductionConfig"
		Set tProps("CSPZENEnabled") = 1
		Set tProps("AutheEnabled") = 32
		// AutheEnabled : 32 = Password. Adaptez si Kerberos/LDAP/DelegatedAuth.
		Set tProps("IsNameSpaceDefault") = 0
		Set tSC = ##class(Security.Applications).Create(pWebApp, .tProps)
		If $$$ISERR(tSC) Quit tSC
		Write "Application web ", pWebApp, " creee.", !
	}
	Else {
		Kill tProps
		Set tProps("MatchRoles") = ":%Ens_ProductionConfig"
		Set tSC = ##class(Security.Applications).Modify(pWebApp, .tProps)
		If $$$ISERR(tSC) Quit tSC
		Write "Application web ", pWebApp, " mise a jour.", !
	}

	// 4) Evenement d'audit personnalise (trace des modifications par host)
	If '##class(Security.Events).Exists("%DA_ProductionOperator/Configure/ModifyItem") {
		Set tSC = ##class(Security.Events).Create("%DA_ProductionOperator", "Configure", "ModifyItem", 1, 0, "Modification reglage restreint (Enabled/Comment/Category)")
		If $$$ISERR(tSC) Quit tSC
		Write "Evenement d'audit %DA_ProductionOperator/Configure/ModifyItem cree.", !
	}
	Else {
		// S'assurer qu'il est actif
		Do ##class(Security.Events).Enable("%DA_ProductionOperator/Configure/ModifyItem")
	}

	Write !, "Installation terminee.", !
	Write "URL operateur : http://<serveur>/<port>", pWebApp, "/DA.UI.ProductionConfigOperator.zen", !
	Quit $$$OK
}

/// Desinstallation (ressource, role et application web).
ClassMethod Uninstall(pWebApp As %String = "/csp/foch/operator") As %Status
{
	New $NAMESPACE
	Set $NAMESPACE = "%SYS"
	If ##class(Security.Events).Exists("%DA_ProductionOperator/Configure/ModifyItem") Do ##class(Security.Events).Delete("%DA_ProductionOperator/Configure/ModifyItem")
	If ##class(Security.Applications).Exists(pWebApp) Do ##class(Security.Applications).Delete(pWebApp)
	If ##class(Security.Roles).Exists("interop_operator_Role") Do ##class(Security.Roles).Delete("interop_operator_Role")
	If ##class(Security.Resources).Exists("%DA_ProductionOperator") Do ##class(Security.Resources).Delete("%DA_ProductionOperator")
	Write "Desinstallation terminee.", !
	Quit $$$OK
}

}
