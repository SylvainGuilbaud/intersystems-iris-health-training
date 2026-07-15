Include %occInclude

/// Installation de la sécurité pour la page DA.UI.ProductionConfigOperator.
///
/// Principe de délégation de privilège :
///  - L'opérateur reçoit uniquement la ressource DA_ProductionOperator (ouvrir la page).
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
	If '##class(Security.Resources).Exists("DA_ProductionOperator") {
		Set tSC = ##class(Security.Resources).Create("DA_ProductionOperator", "Acces page operateur reglages restreints (Enabled/Comment/Category)", "")
		If $$$ISERR(tSC) Quit tSC
		Write "Ressource DA_ProductionOperator creee.", !
	}

	// 2) Role operateur restreint
	//    Ressources minimales : ouvrir la page + acces portail + demarrer/arreter la prod.
	//    NB : PAS de %Ens_ProductionConfig ici (fourni par l'application web).
	Set tResList = "DA_ProductionOperator:U,%Ens_Portal:U,%Ens_ProductionRun:U"
	If '##class(Security.Roles).Exists("interop_operator_Role") {
		Set tSC = ##class(Security.Roles).Create("interop_operator_Role", "Operateur interoperabilite restreint", tResList)
		If $$$ISERR(tSC) Quit tSC
		Write "Role interop_operator_Role cree.", !
	}
	Else {
		// Fusionne les ressources manquantes sans ecraser l'existant.
		Set tSC = ##class(Security.Roles).Get("interop_operator_Role", .tRoleProps)
		If $$$ISERR(tSC) Quit tSC
		Set tCur = $Get(tRoleProps("Resources"))
		For j = 1:1:$Length(tResList, ",") {
			Set tPair = $Piece(tResList, ",", j)
			Set tRes = $Piece(tPair, ":")
			Set tHas = 0
			For k = 1:1:$Length(tCur, ",") {
				If ($Piece($Piece(tCur, ",", k), ":") = tRes) Set tHas = 1 Quit
			}
			If 'tHas Set tCur = tCur _ $Select(tCur = "":"", 1:",") _ tPair
		}
		Set tRoleProps("Resources") = tCur
		Set tSC = ##class(Security.Roles).Modify("interop_operator_Role", .tRoleProps)
		If $$$ISERR(tSC) Quit tSC
		Write "Role interop_operator_Role mis a jour.", !
	}

	// 2b) Role d'escalade : porte %Ens_ProductionConfig (edition) + %Ens_Code (recompilation).
	//     Il n'est donne A PERSONNE directement ; il est accorde par l'application web
	//     ci-dessous (MatchRoles) uniquement le temps d'utiliser la page restreinte.
	Set tEscRes = "%Ens_ProductionConfig:U,%Ens_Code:U"
	If '##class(Security.Roles).Exists("DA_ProductionConfigEscalation") {
		Set tSC = ##class(Security.Roles).Create("DA_ProductionConfigEscalation", "Escalade edition production (page operateur restreinte)", tEscRes)
		If $$$ISERR(tSC) Quit tSC
		Write "Role DA_ProductionConfigEscalation cree.", !
	}

	// 3) Application web dediee, avec escalade vers %Ens_ProductionConfig via un ROLE.
	//    MatchRoles=":DA_ProductionConfigEscalation" => accorde ce ROLE a TOUT utilisateur de l'app.
	If '##class(Security.Applications).Exists(pWebApp) {
		Kill tProps
		Set tProps("NameSpace") = pNamespace
		Set tProps("Description") = "Page operateur reglages restreints (Enabled/Comment/Category)"
		Set tProps("Resource") = "DA_ProductionOperator"
		Set tProps("MatchRoles") = ":DA_ProductionConfigEscalation"
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
		Set tProps("MatchRoles") = ":DA_ProductionConfigEscalation"
		Set tSC = ##class(Security.Applications).Modify(pWebApp, .tProps)
		If $$$ISERR(tSC) Quit tSC
		Write "Application web ", pWebApp, " mise a jour.", !
	}

	// 4) Evenement d'audit personnalise (trace des modifications par host)
	//    Best-effort : ne bloque jamais l'installation si l'API differe selon la version.
	Try {
		If '##class(Security.Events).Exists("DA_ProductionOperator/Configure/ModifyItem") {
			Set tSC2 = ##class(Security.Events).Create("DA_ProductionOperator", "Configure", "ModifyItem", 1, 0, "Modification reglage restreint (Enabled/Comment/Category)")
			If $$$ISOK(tSC2) Write "Evenement d'audit DA_ProductionOperator/Configure/ModifyItem cree.", !
			Else  Write "Avertissement audit : ", $System.Status.GetOneErrorText(tSC2), !
		}
		Else {
			Kill tEvProps
			Set tEvProps("Enabled") = 1
			Do ##class(Security.Events).Modify("DA_ProductionOperator/Configure/ModifyItem", .tEvProps)
			Write "Evenement d'audit DA_ProductionOperator/Configure/ModifyItem deja present.", !
		}
	}
	Catch ex {
		Write "Avertissement audit (ignore) : ", ex.DisplayString(), !
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
	If ##class(Security.Events).Exists("DA_ProductionOperator/Configure/ModifyItem") Do ##class(Security.Events).Delete("DA_ProductionOperator/Configure/ModifyItem")
	If ##class(Security.Applications).Exists(pWebApp) Do ##class(Security.Applications).Delete(pWebApp)
	If ##class(Security.Roles).Exists("DA_ProductionConfigEscalation") Do ##class(Security.Roles).Delete("DA_ProductionConfigEscalation")
	// interop_operator_Role est un role preexistant : on retire seulement la ressource ajoutee, on NE le supprime PAS.
	If ##class(Security.Roles).Exists("interop_operator_Role") {
		Do ##class(Security.Roles).Get("interop_operator_Role", .rr)
		Set rc = ""
		For i = 1:1:$Length($Get(rr("Resources")), ",") {
			Set p = $Piece(rr("Resources"), ",", i)
			If ($Piece(p, ":") '= "DA_ProductionOperator") Set rc = rc _ $Select(rc = "":"", 1:",") _ p
		}
		Set rr("Resources") = rc
		Do ##class(Security.Roles).Modify("interop_operator_Role", .rr)
	}
	If ##class(Security.Resources).Exists("DA_ProductionOperator") Do ##class(Security.Resources).Delete("DA_ProductionOperator")
	Write "Desinstallation terminee.", !
	Quit $$$OK
}

}
