Include (%occInclude, Ensemble)

/// Page opérateur à privilèges restreints, dérivée du portail Interoperability.
/// Elle n'expose QUE trois propriétés par host (BS / BP / BO) :
///  - Enabled  (activer / désactiver)
///  - Comment  (commentaire)
///  - Category (catégorie)
///
/// Tout le reste de la configuration (adaptateurs, File Path, host settings…)
/// est volontairement inaccessible. L'accès à la page est protégé par la
/// ressource DA_ProductionOperator (attribuée au rôle interop_operator_Role).
///
/// L'écriture de la configuration nécessite %Ens_ProductionConfig : ce privilège
/// n'est PAS donné à l'opérateur directement, mais accordé par l'application web
/// qui héberge la page (rôle applicatif / escalade). Voir DA.Setup.
Class DA.UI.ProductionConfigOperator Extends EnsPortal.Template.standardPage
{

/// Domaine de localisation propre à l'application, stocké dans la base
/// utilisateur (inscriptible). Sans cela, ZEN hérite du domaine "Ensemble"
/// dont le dictionnaire de messages est en base ENSLIB (lecture seule),
/// ce qui provoque une erreur <PROTECT> à la compilation des libellés.
Parameter DOMAIN = "DA";

/// Titre affiché dans l'entête du portail.
Parameter PAGENAME = "Réglages restreints de la production";

/// Ressource requise pour OUVRIR la page (à donner au rôle interop_operator_Role).
Parameter RESOURCE = "DA_ProductionOperator";

/// Aucune ressource d'édition supplémentaire : le contrôle se fait dans le code serveur.
Parameter EDITRESOURCE = "DA_ProductionOperator";

/// Production ciblée (par défaut : la production active). Surchargeable via ?PRODUCTION=
Property productionName As %String(ZENURL = "PRODUCTION");

XData Style
{
<style type="text/css">
#tblItems {
	overflow: auto;
	height: 520px;
	border: 1px solid #C4D6D6;
}
.detailForm {
	padding: 12px 18px;
	border: 1px solid #C4D6D6;
	background: #F7F9F9;
	margin-left: 14px;
	min-width: 460px;
}
.detailForm .zenLabel {
	font-weight: 600;
	color: #325158;
}
.pageHint {
	color: #606060;
	font-size: 0.85em;
	padding: 4px 0 10px 2px;
}
.typeBadge { font-weight: 600; }
</style>
}

XData Contents [ XMLNamespace = "http://www.intersystems.com/zen" ]
{
<page xmlns="http://www.intersystems.com/zen" title="">
<vgroup width="100%">
<html id="hint" OnDrawContent="DrawHint"/>
<hgroup width="100%" cellVAlign="top">
 <tablePane id="tblItems"
	queryClass="DA.UI.ProductionConfigOperator"
	queryName="ItemList"
	valueColumn="Name"
	maxRows="2000"
	pageSize="0"
	useSnapshot="false"
	showZebra="true"
	onselectrow="zenPage.selectItem(zenThis.getValue());">
  <parameter value="#(%page.productionName)#"/>
  <column colName="Name" header="Host"/>
  <column colName="TypeLabel" header="Type"/>
  <column colName="Enabled" header="Activé"/>
  <column colName="Category" header="Catégorie"/>
 </tablePane>

 <form id="frmDetail" cellStyle="padding:4px;" enclosingClass="detailForm">
  <text id="fName" label="Host sélectionné" size="50" readOnly="true"/>
  <text id="fType" label="Type" size="10" readOnly="true"/>
  <checkbox id="fEnabled" label="Activé (Enabled)"/>
  <text id="fCategory" label="Catégorie (Category)" size="60"/>
  <textarea id="fComment" label="Commentaire (Comment)" rows="5" cols="58"/>
  <spacer height="8"/>
  <hgroup>
   <button caption="Enregistrer" controlClass="commandButton" onclick="zenPage.save();"/>
   <spacer width="10"/>
   <button caption="Annuler" controlClass="commandButtonRemove" onclick="zenPage.reload();"/>
  </hgroup>
 </form>
</hgroup>
</vgroup>
</page>
}

/// Bandeau d'aide en haut de page.
Method DrawHint(pSeed As %String) As %Status
{
	Write "<div class='pageHint'>Production : <b>", $ZCVT(..productionName, "O", "HTML"),
		"</b> &mdash; vous pouvez modifier uniquement <b>Enabled</b>, <b>Comment</b> et <b>Category</b> pour chaque Service (BS), Process (BP) ou Operation (BO).</div>"
	Quit $$$OK
}

Method %OnAfterCreatePage() As %Status
{
	Set tSC = ##super()
	If $$$ISERR(tSC) Quit tSC
	If (..productionName = "") {
		Set ..productionName = ##class(Ens.Director).GetActiveProductionName()
	}
	Quit $$$OK
}

/// Nom de page (entête / onglet).
Method %OnGetPageName() As %String
{
	Quit ..#PAGENAME
}

/// Liste des hosts de la production, limitée aux colonnes affichées.
Query ItemList(pProduction As %String) As %Query(ROWSPEC = "Name:%String,TypeLabel:%String,Enabled:%Boolean,Category:%String") [ SqlProc ]
{
}

ClassMethod ItemListExecute(ByRef qHandle As %Binary, pProduction As %String) As %Status
{
	Kill ^||DA.ItemList
	Set qHandle = 0
	If (pProduction = "") Set pProduction = ##class(Ens.Director).GetActiveProductionName()
	If (pProduction = "") Quit $$$OK
	Set tProd = ##class(Ens.Config.Production).%OpenId(pProduction, , .tSC)
	If '$IsObject(tProd) Quit tSC
	For i = 1:1:tProd.Items.Count() {
		Set tItem = tProd.Items.GetAt(i)
		Set tType = tItem.BusinessType()
		Set tLabel = $Case(tType, 1:"BS", 2:"BP", 3:"BO", :"?")
		Set n = $Increment(^||DA.ItemList)
		Set ^||DA.ItemList(n) = $ListBuild(tItem.Name, tLabel, +tItem.Enabled, tItem.Category)
	}
	Quit $$$OK
}

ClassMethod ItemListFetch(ByRef qHandle As %Binary, ByRef Row As %List, ByRef AtEnd As %Integer) As %Status
{
	Set qHandle = $Order(^||DA.ItemList(qHandle))
	If (qHandle = "") {
		Set Row = "", AtEnd = 1
		Quit $$$OK
	}
	Set Row = ^||DA.ItemList(qHandle)
	If ($Order(^||DA.ItemList(qHandle)) = "") Set AtEnd = 1
	Quit $$$OK
}

ClassMethod ItemListClose(ByRef qHandle As %Binary) As %Status
{
	Kill ^||DA.ItemList
	Quit $$$OK
}

/// Charge les 3 valeurs éditables d'un host (appelé au clic sur une ligne).
ClassMethod LoadItem(pProduction As %String, pName As %String) As %ZEN.proxyObject [ ZenMethod ]
{
	Set tObj = ##class(%ZEN.proxyObject).%New()
	Set tObj.name = pName
	Set tObj.type = ""
	Set tObj.enabled = 0
	Set tObj.comment = ""
	Set tObj.category = ""
	If (pProduction = "") Set pProduction = ##class(Ens.Director).GetActiveProductionName()
	Set tProd = ##class(Ens.Config.Production).%OpenId(pProduction, , .tSC)
	If $IsObject(tProd) {
		For i = 1:1:tProd.Items.Count() {
			Set tItem = tProd.Items.GetAt(i)
			If (tItem.Name = pName) {
				Set tObj.type = $Case(tItem.BusinessType(), 1:"BS", 2:"BP", 3:"BO", :"?")
				Set tObj.enabled = +tItem.Enabled
				Set tObj.comment = tItem.Comment
				Set tObj.category = tItem.Category
				Quit
			}
		}
	}
	Quit tObj
}

/// Enregistre UNIQUEMENT Enabled / Comment / Category pour le host indiqué.
/// Retourne "1" en cas de succès, sinon le texte de l'erreur.
ClassMethod SaveItem(pProduction As %String, pName As %String, pEnabled As %Boolean, pComment As %String, pCategory As %String) As %String [ ZenMethod ]
{
	Set tSC = ..ApplyItem(pProduction, pName, pEnabled, pComment, pCategory)
	If $$$ISOK(tSC) Quit "1"
	Quit $System.Status.GetOneErrorText(tSC)
}

/// Coeur de l'écriture : ouvre la production, ne touche QUE les 3 propriétés
/// autorisées, sauvegarde la classe et applique à la production en cours.
ClassMethod ApplyItem(pProduction As %String, pName As %String, pEnabled As %Boolean, pComment As %String, pCategory As %String) As %Status
{
	If (pProduction = "") Set pProduction = ##class(Ens.Director).GetActiveProductionName()
	If (pProduction = "") Quit $$$ERROR($$$GeneralError, "Aucune production active")

	// Verifie l'escalade de privileges : sans %Ens_ProductionConfig:USE (edition) et
	// %Ens_Code:USE (recompilation), SaveToClass echouerait silencieusement.
	// Ces privileges sont fournis par l'application web d'escalade (.../operator/).
	If '$System.Security.Check("%Ens_ProductionConfig", "USE") {
		Quit $$$ERROR($$$GeneralError, "Privilege %Ens_ProductionConfig:USE manquant. Ouvrez la page via l'application d'escalade (.../operator/DA.UI.ProductionConfigOperator.zen).")
	}
	If '$System.Security.Check("%Ens_Code", "USE") {
		Quit $$$ERROR($$$GeneralError, "Privilege %Ens_Code:USE manquant. Ouvrez la page via l'application d'escalade (.../operator/DA.UI.ProductionConfigOperator.zen).")
	}

	Set tProd = ##class(Ens.Config.Production).%OpenId(pProduction, , .tSC)
	If '$IsObject(tProd) Quit $$$ADDSC($$$ERROR($$$GeneralError, "Production introuvable : " _ pProduction), tSC)

	Set tItem = tProd.FindItemByConfigName(pName)
	If '$IsObject(tItem) Quit $$$ERROR($$$GeneralError, "Host introuvable : " _ pName)

	// Anciennes valeurs (pour la trace d'audit)
	Set tOldEnabled = +tItem.Enabled
	Set tOldComment = tItem.Comment
	Set tOldCategory = tItem.Category

	// Ne touche QUE les trois proprietes autorisees.
	Set tItem.Enabled = +pEnabled
	Set tItem.Comment = pComment
	Set tItem.Category = pCategory

	// Persiste la modification dans la classe de production (et recompile).
	Set tSC = tProd.SaveToClass()
	If $$$ISERR(tSC) Quit tSC

	// Verifie reellement la persistance (SaveToClass peut renvoyer OK sans ecrire).
	Set tCheck = ##class(Ens.Config.Production).%OpenId(pProduction)
	If $IsObject(tCheck) {
		Set tCheckItem = tCheck.FindItemByConfigName(pName)
		If $IsObject(tCheckItem), (tCheckItem.Comment '= pComment) || (tCheckItem.Category '= pCategory) || (+tCheckItem.Enabled '= +pEnabled) {
			Quit $$$ERROR($$$GeneralError, "La sauvegarde n'a pas ete persistee (privileges insuffisants ?).")
		}
	}

	// Applique a la production en cours d'execution (prend en compte Enabled).
	If (##class(Ens.Director).GetActiveProductionName() = pProduction) {
		Set tSC = ##class(Ens.Director).UpdateProduction(10, 1)
	}
	If $$$ISERR(tSC) Quit tSC

	// Journal d'audit : trace le qui / quoi / avant / apres.
	Do ..Audit(pProduction, pName, tOldEnabled, +pEnabled, tOldComment, pComment, tOldCategory, pCategory)
	Quit tSC
}

/// Ecrit un evenement dans la base d'audit IRIS (best-effort : n'echoue jamais l'enregistrement).
/// L'evenement DA_ProductionOperator/Configure/ModifyItem est cree par DA.Setup.
ClassMethod Audit(pProduction As %String, pName As %String, pOldEnabled As %Boolean, pNewEnabled As %Boolean, pOldComment As %String, pNewComment As %String, pOldCategory As %String, pNewCategory As %String) As %Status
{
	Set tChanges = ""
	If (pOldEnabled '= pNewEnabled) Set tChanges = tChanges _ "Enabled: " _ pOldEnabled _ " -> " _ pNewEnabled _ "; "
	If (pOldComment '= pNewComment) Set tChanges = tChanges _ "Comment: [" _ pOldComment _ "] -> [" _ pNewComment _ "]; "
	If (pOldCategory '= pNewCategory) Set tChanges = tChanges _ "Category: [" _ pOldCategory _ "] -> [" _ pNewCategory _ "]; "
	If (tChanges = "") Set tChanges = "(aucun changement effectif)"

	Set tData = "Production=" _ pProduction _ " | Host=" _ pName _ " | " _ tChanges
	Set tDescr = "Modification reglages restreints par " _ $Username

	// Ne fait pas echouer la sauvegarde si l'audit est indisponible.
	Set tSC = $$$OK
	Try {
		Set tSC = $SYSTEM.Security.Audit("DA_ProductionOperator", "Configure", "ModifyItem", tData, tDescr)
	}
	Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

/// Sélection d'une ligne : charge le formulaire de détail.
ClientMethod selectItem(name) [ Language = javascript ]
{
	if (!name) return;
	var p = zenPage.LoadItem(this.productionName, name);
	zen('fName').setValue(p.name);
	zen('fType').setValue(p.type);
	zen('fEnabled').setValue(p.enabled == 1);
	zen('fCategory').setValue(p.category);
	zen('fComment').setValue(p.comment);
}

/// Enregistrement des 3 champs autorisés.
ClientMethod save() [ Language = javascript ]
{
	var name = zen('fName').getValue();
	if (!name) { alert('Sélectionnez d\'abord un host dans la liste.'); return; }
	var enabled = zen('fEnabled').getValue() ? 1 : 0;
	var res = zenPage.SaveItem(this.productionName, name, enabled, zen('fComment').getValue(), zen('fCategory').getValue());
	if (res == '1') {
		alert('Modifications enregistrées.');
		zen('tblItems').executeQuery(1);
	}
	else {
		alert('Erreur lors de l\'enregistrement :\n' + res);
	}
}

/// Recharge la page (bouton Annuler).
ClientMethod reload() [ Language = javascript ]
{
	self.document.location.reload();
}

}
