Include Ensemble

/// Builders and parsers for the IHE LAW (Laboratory Analytical Workflow) HL7 v2.5.1 messages.
/// <ul>
/// <li>LAB-27 Query for AWOS: QBP^Q11 (Automate -> Analyzer Manager), answered by RSP^K11</li>
/// <li>LAB-28 AWOS Broadcast: OML^O33 (Analyzer Manager -> Automate), answered by ORL^O34</li>
/// <li>LAB-29 AWOS Status Change: OUL^R22 (Automate -> Analyzer Manager), answered by ACK</li>
/// </ul>
/// AWOS = Analytical Work Order Step. All the builders return a string whose segments are
/// separated by $C(13), ready for EnsLib.HL7.Message:ImportFromString().
Class DGLAB.law.Messages Extends %RegisteredObject
{

Parameter VERSION = "2.5.1";

/// Name of the code system used for the simulated analytical tests
Parameter CODESYSTEM = "L";

/// Default tests simulated by the Analyzer Manager (code^text^codesystem), separated by ";"
Parameter DEFAULTTESTS = "296^S-Sodium^L;297^S-Potassium^L;298^S-Chloride^L";

/// Current timestamp, YYYYMMDDHHMMSS
ClassMethod Now() As %String
{
	Quit $Translate($ZDateTime($Horolog, 3), " -:")
}

/// Unique message control id
ClassMethod NextId(pPrefix As %String = "LAW") As %String
{
	Quit pPrefix _ $Translate($Justify($Increment(^DGLAB.law.Seq), 8), " ", "0")
}

/// MSH segment. pTransaction is the IHE transaction id (LAB-27, LAB-28, LAB-29).
ClassMethod MSH(pType As %String, pCtrlId As %String, pTransaction As %String, pSendApp As %String, pSendFac As %String, pRecvApp As %String, pRecvFac As %String) As %String
{
	Quit "MSH|^~\&|" _ pSendApp _ "|" _ pSendFac _ "|" _ pRecvApp _ "|" _ pRecvFac _ "|" _ ..Now() _ "||" _ pType _ "|" _ pCtrlId _ "|P|" _ ..#VERSION _ "|||NE|AL||UNICODE UTF-8|||" _ pTransaction _ "^IHE"
}

/// Joins segments with the HL7 segment terminator
ClassMethod Join(ByRef pSegs) As %String
{
	Set tOut = "", i = ""
	For {
		Set i = $Order(pSegs(i), 1, tSeg)
		Quit:i=""
		Set tOut = tOut _ $Select(tOut="":"", 1:$Char(13)) _ tSeg
	}
	Quit tOut
}

/// Returns the list of simulated tests as a $List of code^text^codesystem
ClassMethod TestList(pTests As %String = "") As %List
{
	Set:pTests="" pTests = ..#DEFAULTTESTS
	Set tList = ""
	For i = 1:1:$Length(pTests, ";") {
		Set tT = $ZStrip($Piece(pTests, ";", i), "<>W")
		Set:tT'="" tList = tList _ $ListBuild(tT)
	}
	Quit tList
}

/// LAB-27 - QBP^Q11 Query for AWOS, sent by the Automate to the Analyzer Manager.
/// pContainerId identifies the specimen container (tube) that has just arrived on the analyzer.
ClassMethod QBP(pContainerId As %String, pQueryTag As %String = "", pSendApp As %String = "ANALYZER", pSendFac As %String = "LAB", pRecvApp As %String = "LIS", pRecvFac As %String = "LAB", pCtrlId As %String = "") As %String
{
	Set:pCtrlId="" pCtrlId = ..NextId("QBP")
	Set:pQueryTag="" pQueryTag = "Q" _ ..Now()
	Set tSeg($Increment(tSeg)) = ..MSH("QBP^Q11^QBP_Q11", pCtrlId, "LAB-27", pSendApp, pSendFac, pRecvApp, pRecvFac)
	Set tSeg($Increment(tSeg)) = "QPD|WOS^Work Order Step^IHE_LABTF|" _ pQueryTag _ "|" _ pContainerId
	Set tSeg($Increment(tSeg)) = "RCP|I||R"
	Quit ..Join(.tSeg)
}

/// LAB-27 - RSP^K11 answer to a QBP^Q11. It only acknowledges the query: the work orders
/// themselves are transmitted separately in an OML^O33 (LAB-28).
/// pQBP is the received QBP^Q11 as a string, pFound tells if work orders exist for the container.
ClassMethod RSP(pQBP As %String, pFound As %Boolean = 1) As %String
{
	Set tMsh = ..Segment(pQBP, "MSH"), tQpd = ..Segment(pQBP, "QPD")
	Set tSeg($Increment(tSeg)) = ..MSH("RSP^K11^RSP_K11", ..NextId("RSP"), "LAB-27", ..Field(tMsh, "MSH", 5), ..Field(tMsh, "MSH", 6), ..Field(tMsh, "MSH", 3), ..Field(tMsh, "MSH", 4))
	Set tSeg($Increment(tSeg)) = "MSA|AA|" _ ..Field(tMsh, "MSH", 10)
	Set tSeg($Increment(tSeg)) = "QAK|" _ ..Field(tQpd, "QPD", 2) _ "|" _ $Select(pFound:"OK", 1:"NF")
	Set tSeg($Increment(tSeg)) = tQpd
	Quit ..Join(.tSeg)
}

/// LAB-28 - OML^O33 AWOS Broadcast, sent by the Analyzer Manager to the Automate.
/// One SPM/SAC specimen group with one ORC/TQ1/OBR order per test.
ClassMethod OML(pContainerId As %String, pPatient As %DynamicObject = "", pTests As %String = "", pSendApp As %String = "LIS", pSendFac As %String = "LAB", pRecvApp As %String = "ANALYZER", pRecvFac As %String = "LAB", pCtrlId As %String = "") As %String
{
	Set:pCtrlId="" pCtrlId = ..NextId("OML")
	Set:'$IsObject(pPatient) pPatient = ..DefaultPatient()
	Set tNow = ..Now(), tSpecimen = "SP" _ pContainerId
	Set tSeg($Increment(tSeg)) = ..MSH("OML^O33^OML_O33", pCtrlId, "LAB-28", pSendApp, pSendFac, pRecvApp, pRecvFac)
	Set tSeg($Increment(tSeg)) = ..PID(pPatient)
	// In the HL7 2.5.1 OML_O33 definition an SPM group carries one order (ORC/TQ1/OBR):
	// the specimen and its container are repeated for each test of the container.
	Set tTests = ..TestList(pTests)
	Set tPtr = 0, n = 0
	While $ListNext(tTests, tPtr, tTest) {
		Set n = n + 1, tOrder = ..OrderNumber(pContainerId, n)
		Set tSeg($Increment(tSeg)) = "SPM|" _ n _ "|" _ tSpecimen _ "^LIS||BLD^Blood^HL70487|||||||P^Patient^HL70369|||||||" _ tNow
		Set tSeg($Increment(tSeg)) = "SAC|||" _ pContainerId
		Set tSeg($Increment(tSeg)) = "ORC|NW|" _ tOrder _ "^LIS|" _ tOrder _ "^LIS"
		Set tSeg($Increment(tSeg)) = "TQ1|1||||||||R"
		Set tSeg($Increment(tSeg)) = "OBR|" _ n _ "|" _ tOrder _ "^LIS|" _ tOrder _ "^LIS|" _ tTest _ "|||" _ tNow
	}
	Quit ..Join(.tSeg)
}

/// LAB-28 - ORL^O34 answer to an OML^O33, sent by the Automate (accepts every order).
ClassMethod ORL(pOML As %String) As %String
{
	Set tMsh = ..Segment(pOML, "MSH")
	Set tSeg($Increment(tSeg)) = ..MSH("ORL^O34^ORL_O34", ..NextId("ORL"), "LAB-28", ..Field(tMsh, "MSH", 5), ..Field(tMsh, "MSH", 6), ..Field(tMsh, "MSH", 3), ..Field(tMsh, "MSH", 4))
	Set tSeg($Increment(tSeg)) = "MSA|AA|" _ ..Field(tMsh, "MSH", 10)
	// The HL7 2.5.1 ORL_O34 definition requires the PID before the specimen groups
	Set tPid = ..Segment(pOML, "PID")
	Set:tPid'="" tSeg($Increment(tSeg)) = tPid
	// One SPM/SAC/ORC group per received order, status OK = order accepted
	Set tSpms = ..Segments(pOML, "SPM"), tSacs = ..Segments(pOML, "SAC"), tOrcs = ..Segments(pOML, "ORC")
	For i = 1:1:$ListLength(tOrcs) {
		Set tOrc = $ListGet(tOrcs, i)
		Set tSeg($Increment(tSeg)) = $ListGet(tSpms, i, $ListGet(tSpms, 1))
		Set tSeg($Increment(tSeg)) = $ListGet(tSacs, i, $ListGet(tSacs, 1))
		Set tSeg($Increment(tSeg)) = "ORC|OK|" _ ..Field(tOrc, "ORC", 2) _ "|" _ ..Field(tOrc, "ORC", 3)
	}
	Quit ..Join(.tSeg)
}

/// LAB-29 - OUL^R22 AWOS Status Change: status and results, sent by the Automate to the Analyzer Manager.
/// pValues is a $List of result values, one per test, in the order of the tests (a value of "" gives no result).
ClassMethod OUL(pContainerId As %String, pPatient As %DynamicObject = "", pTests As %String = "", pValues As %List = "", pSendApp As %String = "ANALYZER", pSendFac As %String = "LAB", pRecvApp As %String = "LIS", pRecvFac As %String = "LAB", pCtrlId As %String = "") As %String
{
	Set:pCtrlId="" pCtrlId = ..NextId("OUL")
	Set:'$IsObject(pPatient) pPatient = ..DefaultPatient()
	Set tNow = ..Now(), tSpecimen = "SP" _ pContainerId
	Set tSeg($Increment(tSeg)) = ..MSH("OUL^R22^OUL_R22", pCtrlId, "LAB-29", pSendApp, pSendFac, pRecvApp, pRecvFac)
	Set tSeg($Increment(tSeg)) = ..PID(pPatient)
	Set tSeg($Increment(tSeg)) = "SPM|1|" _ tSpecimen _ "^LIS||BLD^Blood^HL70487|||||||P^Patient^HL70369|||||||" _ tNow
	Set tSeg($Increment(tSeg)) = "SAC|||" _ pContainerId
	Set tTests = ..TestList(pTests)
	Set tPtr = 0, n = 0
	While $ListNext(tTests, tPtr, tTest) {
		Set n = n + 1, tOrder = ..OrderNumber(pContainerId, n)
		Set tValue = $ListGet(pValues, n)
		// In the HL7 2.5.1 OUL_R22 definition the ORC follows its OBR
		Set tSeg($Increment(tSeg)) = "OBR|" _ n _ "|" _ tOrder _ "^LIS|" _ tOrder _ "^LIS|" _ tTest _ "|||" _ tNow _ $Translate($Justify("", 18), " ", "|") _ $Select(tValue="":"I", 1:"F")
		Set tSeg($Increment(tSeg)) = "ORC|SC|" _ tOrder _ "^LIS|" _ tOrder _ "^LIS||" _ $Select(tValue="":"IP", 1:"CM")
		Set:tValue'="" tSeg($Increment(tSeg)) = "OBX|1|NM|" _ tTest _ "||" _ tValue _ "|mmol/L^mmol/L^UCUM||N|||F|||" _ tNow
	}
	Quit ..Join(.tSeg)
}

/// LAB-29 - ACK answer to an OUL^R22
ClassMethod ACK(pRequest As %String, pCode As %String = "AA") As %String
{
	Set tMsh = ..Segment(pRequest, "MSH")
	Set tTrigger = $Piece(..Field(tMsh, "MSH", 9), "^", 2)
	Set tSeg($Increment(tSeg)) = ..MSH("ACK^" _ tTrigger _ "^ACK", ..NextId("ACK"), "LAB-29", ..Field(tMsh, "MSH", 5), ..Field(tMsh, "MSH", 6), ..Field(tMsh, "MSH", 3), ..Field(tMsh, "MSH", 4))
	Set tSeg($Increment(tSeg)) = "MSA|" _ pCode _ "|" _ ..Field(tMsh, "MSH", 10)
	Quit ..Join(.tSeg)
}

/// Default simulated patient (same demo patient as the rest of the training)
ClassMethod DefaultPatient() As %DynamicObject
{
	Quit {"id":"24445670", "lastName":"VERSAIRE", "firstName":"Anne", "dob":"19850124", "gender":"F"}
}

/// PID segment from a patient object {id,lastName,firstName,dob,gender}
ClassMethod PID(pPatient As %DynamicObject) As %String
{
	Quit "PID|1||" _ pPatient.id _ "^^^LAB^PI||" _ pPatient.lastName _ "^" _ pPatient.firstName _ "||" _ pPatient.dob _ "|" _ pPatient.gender
}

/// Placer/filler order number derived from the container id and the order rank
ClassMethod OrderNumber(pContainerId As %String, pRank As %Integer) As %String
{
	Quit pContainerId _ "-" _ pRank
}

/// First segment named pName of a message string (segments separated by CR and/or LF)
ClassMethod Segment(pMessage As %String, pName As %String) As %String
{
	Set tSegs = ..Segments(pMessage, pName)
	Quit $ListGet(tSegs, 1)
}

/// All the segments named pName of a message string, as a $List
ClassMethod Segments(pMessage As %String, pName As %String) As %List
{
	Set tMsg = $Translate(pMessage, $Char(10), $Char(13)), tList = ""
	For i = 1:1:$Length(tMsg, $Char(13)) {
		Set tSeg = $Piece(tMsg, $Char(13), i)
		Set:$Piece(tSeg, "|", 1)=pName tList = tList _ $ListBuild(tSeg)
	}
	Quit tList
}

/// Field number pN of a segment (HL7 numbering: for the MSH segment the field separator is MSH-1)
ClassMethod Field(pSegment As %String, pName As %String, pN As %Integer) As %String
{
	Quit $Piece(pSegment, "|", $Select(pName="MSH":pN, 1:pN + 1))
}

}
