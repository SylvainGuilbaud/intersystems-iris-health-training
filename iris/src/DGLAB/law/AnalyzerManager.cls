Include Ensemble

/// Simulator of the IHE LAW (Laboratory Analytical Workflow) peer systems.
/// <ul>
/// <li>LAB-27 QBP^Q11: plays the Analyzer Manager. Answers with a RSP^K11 and, when a work order broadcast
///     target is configured, broadcasts the work orders in an OML^O33 (LAB-28) to that target.</li>
/// <li>LAB-28 OML^O33: plays the Automate (analyzer). Accepts every order and answers with an ORL^O34.</li>
/// <li>LAB-29 OUL^R22: plays the Analyzer Manager. Takes the statuses/results into account and answers with an ACK.</li>
/// </ul>
/// The three transactions can be sent by any HL7 service (HTTP, MLLP, FILE) that targets this process
/// with the service setting AckMode=App, so that the answer is returned to the sender.
Class DGLAB.law.AnalyzerManager Extends Ens.BusinessProcess
{

/// Business operation that receives the OML^O33 broadcast (LAB-28) after a LAB-27 query.
/// Leave empty to answer the query without broadcasting the work orders.
Property AwosBroadcastTarget As Ens.DataType.ConfigName;

/// Tests simulated for each container, separated by ";" (code^text^codesystem)
Property Tests As %String(MAXLEN = 500) [ InitialExpression = {##class(DGLAB.law.Messages).#DEFAULTTESTS} ];

/// Containers whose id starts with this prefix have no work order (the RSP^K11 answers NF - no data found)
Property UnknownContainerPrefix As %String [ InitialExpression = "UNKNOWN" ];

Parameter SETTINGS = "AwosBroadcastTarget:LAW:selector?context={Ens.ContextSearch/ProductionItems?targets=1&productionName=@productionId},Tests:LAW,UnknownContainerPrefix:LAW";

Method OnRequest(pRequest As EnsLib.HL7.Message, Output pResponse As EnsLib.HL7.Message) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tRaw = pRequest.OutputToString(,,.tSC)
		Quit:$$$ISERR(tSC)

		Set tType = $Piece(##class(DGLAB.law.Messages).Field(##class(DGLAB.law.Messages).Segment(tRaw, "MSH"), "MSH", 9), "^", 1, 2)
		If tType = "QBP^Q11" {
			Set tReply = ..OnQuery(tRaw)
		} ElseIf tType = "OML^O33" {
			Set tReply = ..OnBroadcast(tRaw)
		} ElseIf tType = "OUL^R22" {
			Set tReply = ..OnStatusChange(tRaw)
		} Else {
			$$$LOGWARNING("Message type " _ tType _ " is not part of the IHE LAW profile")
			Set tReply = ##class(DGLAB.law.Messages).ACK(tRaw, "AR")
		}

		Set pResponse = ##class(EnsLib.HL7.Message).ImportFromString(tReply, .tSC)
		Quit:$$$ISERR(tSC)
		// Resolve the schema (MSH-9.3 message structure) so that the response is validated and routable
		Set pResponse.DocType = ##class(DGLAB.law.Messages).#VERSION _ ":" _ $Piece($Piece(tReply, "|", 9), "^", 3)
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

/// LAB-27 - Query for AWOS (QBP^Q11): answer with RSP^K11, then broadcast the work orders (LAB-28)
Method OnQuery(pQBP As %String) As %String
{
	Set tQpd = ##class(DGLAB.law.Messages).Segment(pQBP, "QPD")
	Set tContainer = $Piece(##class(DGLAB.law.Messages).Field(tQpd, "QPD", 3), "^", 1)
	Set tFound = (tContainer '= "") && ($Extract(tContainer, 1, $Length(..UnknownContainerPrefix)) '= ..UnknownContainerPrefix)
	$$$LOGINFO("LAB-27 Query for AWOS, container " _ tContainer _ $Select(tFound:" - work orders found", 1:" - no work order"))

	If tFound && (..AwosBroadcastTarget '= "") {
		Set tOML = ##class(DGLAB.law.Messages).OML(tContainer, , ..Tests)
		Set tOMLMsg = ##class(EnsLib.HL7.Message).ImportFromString(tOML, .tSC)
		If $$$ISOK(tSC) {
			Set tOMLMsg.DocType = "2.5.1:OML_O33"
			// No response awaited: the LAB-27 answer must not wait for the broadcast target
			Set tSC = ..SendRequestAsync(..AwosBroadcastTarget, tOMLMsg, 0)
		}
		If $$$ISERR(tSC) $$$LOGWARNING("LAB-28 AWOS Broadcast not sent: " _ $System.Status.GetErrorText(tSC))
	}
	Quit ##class(DGLAB.law.Messages).RSP(pQBP, tFound)
}

/// LAB-28 - AWOS Broadcast (OML^O33): the simulated Automate accepts the orders with an ORL^O34
Method OnBroadcast(pOML As %String) As %String
{
	Set tOrders = $ListLength(##class(DGLAB.law.Messages).Segments(pOML, "ORC"))
	Set tContainer = ##class(DGLAB.law.Messages).Field(##class(DGLAB.law.Messages).Segment(pOML, "SAC"), "SAC", 3)
	$$$LOGINFO("LAB-28 AWOS Broadcast, container " _ tContainer _ ": " _ tOrders _ " order(s) accepted")
	Quit ##class(DGLAB.law.Messages).ORL(pOML)
}

/// LAB-29 - AWOS Status Change (OUL^R22): log statuses and results, answer with ACK
Method OnStatusChange(pOUL As %String) As %String
{
	Set tContainer = ##class(DGLAB.law.Messages).Field(##class(DGLAB.law.Messages).Segment(pOUL, "SAC"), "SAC", 3)
	Set tResults = ##class(DGLAB.law.Messages).Segments(pOUL, "OBX"), tPtr = 0, tSummary = ""
	While $ListNext(tResults, tPtr, tObx) {
		Set tSummary = tSummary _ $Select(tSummary="":"", 1:", ") _ $Piece(##class(DGLAB.law.Messages).Field(tObx, "OBX", 3), "^", 2) _ "=" _ ##class(DGLAB.law.Messages).Field(tObx, "OBX", 5)
	}
	$$$LOGINFO("LAB-29 AWOS Status Change, container " _ tContainer _ ": " _ $Select(tSummary="":"no result", 1:tSummary))
	Quit ##class(DGLAB.law.Messages).ACK(pOUL, "AA")
}

/// ORL^O34 answer to the OML^O33 broadcast of a LAB-27 query
Method OnResponse(pRequest As Ens.Request, ByRef pResponse As Ens.Response, pCallrequest As Ens.Request, pCallresponse As Ens.Response, pCompletionKey As %String) As %Status
{
	Quit $$$OK
}

}
