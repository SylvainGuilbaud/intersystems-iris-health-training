/// Unit tests of the IHE LAW simulator.
/// Run from a terminal in the namespace where the classes are loaded:
/// <example>
/// set ^UnitTestRoot = "/tmp/"
/// do ##class(%UnitTest.Manager).RunTest("DGLAB/law", "/noload/nodelete")
/// </example>
Class DGLAB.law.Test Extends %UnitTest.TestCase
{

/// Parses a message with the 2.5.1 schema and returns it
Method Parse(pText As %String, pStructure As %String) As EnsLib.HL7.Message
{
	Set tMsg = ##class(EnsLib.HL7.Message).ImportFromString(pText, .tSC)
	Do $$$AssertStatusOK(tSC, "message " _ pStructure _ " imports")
	Set tMsg.DocType = "2.5.1:" _ pStructure
	Quit tMsg
}

Method TestQBP()
{
	Set tText = ##class(DGLAB.law.Messages).QBP("C0001", "TAG1")
	Set tMsg = ..Parse(tText, "QBP_Q11")
	Do $$$AssertEquals(tMsg.GetValueAt("MSH:9.1"), "QBP", "QBP message code")
	Do $$$AssertEquals(tMsg.GetValueAt("MSH:9.2"), "Q11", "QBP trigger event")
	Do $$$AssertEquals(tMsg.GetValueAt("MSH:12"), "2.5.1", "HL7 version 2.5.1")
	Do $$$AssertEquals(tMsg.GetValueAt("QPD:3"), "C0001", "QPD-3 container id")
	Do $$$AssertEquals(tMsg.GetValueAt("QPD:2"), "TAG1", "QPD-2 query tag")
	Do $$$AssertEquals(tMsg.GetValueAt("MSH:21.1"), "LAB-27", "profile LAB-27")
}

Method TestRSP()
{
	Set tQBP = ##class(DGLAB.law.Messages).QBP("C0001", "TAG1")
	Set tFound = ..Parse(##class(DGLAB.law.Messages).RSP(tQBP, 1), "RSP_K11")
	Do $$$AssertEquals(tFound.GetValueAt("MSH:9.2"), "K11", "RSP trigger event")
	Do $$$AssertEquals(tFound.GetValueAt("MSA:1"), "AA", "RSP accepted")
	Do $$$AssertEquals(tFound.GetValueAt("MSA:2"), ##class(DGLAB.law.Messages).Field(##class(DGLAB.law.Messages).Segment(tQBP, "MSH"), "MSH", 10), "RSP echoes the QBP control id")
	Do $$$AssertEquals(tFound.GetValueAt("QAK:1"), "TAG1", "QAK-1 query tag")
	Do $$$AssertEquals(tFound.GetValueAt("QAK:2"), "OK", "QAK-2 data found")

	Set tNone = ..Parse(##class(DGLAB.law.Messages).RSP(tQBP, 0), "RSP_K11")
	Do $$$AssertEquals(tNone.GetValueAt("QAK:2"), "NF", "QAK-2 no data found")
}

Method TestOMLandORL()
{
	Set tOML = ##class(DGLAB.law.Messages).OML("C0001")
	Set tMsg = ..Parse(tOML, "OML_O33")
	Do $$$AssertEquals(tMsg.GetValueAt("MSH:9.2"), "O33", "OML trigger event")
	Do $$$AssertEquals($ListLength(##class(DGLAB.law.Messages).Segments(tOML, "ORC")), 3, "one ORC per default test")
	Do $$$AssertEquals($ListLength(##class(DGLAB.law.Messages).Segments(tOML, "OBR")), 3, "one OBR per default test")
	Do $$$AssertEquals(tMsg.GetValueAt("SAC:3"), "C0001", "SAC-3 container id")

	Set tORL = ..Parse(##class(DGLAB.law.Messages).ORL(tOML), "ORL_O34")
	Do $$$AssertEquals(tORL.GetValueAt("MSH:9.2"), "O34", "ORL trigger event")
	Do $$$AssertEquals(tORL.GetValueAt("MSA:1"), "AA", "ORL accepted")
	Do $$$AssertEquals($ListLength(##class(DGLAB.law.Messages).Segments(tORL.OutputToString(), "ORC")), 3, "ORL answers every order")
}

Method TestOULandACK()
{
	Set tOUL = ##class(DGLAB.law.Messages).OUL("C0001", , , $ListBuild(143, "4.1", 102))
	Set tMsg = ..Parse(tOUL, "OUL_R22")
	Do $$$AssertEquals(tMsg.GetValueAt("MSH:9.2"), "R22", "OUL trigger event")
	Do $$$AssertEquals($ListLength(##class(DGLAB.law.Messages).Segments(tOUL, "OBX")), 3, "one OBX per result")

	Set tACK = ..Parse(##class(DGLAB.law.Messages).ACK(tOUL), "ACK")
	Do $$$AssertEquals(tACK.GetValueAt("MSA:1"), "AA", "ACK accepted")
}

/// The process answers each transaction with the expected message
Method TestProcess()
{
	Set tProc = ##class(DGLAB.law.AnalyzerManager).%New("LAW Analyzer Manager")
	Set tProc.AwosBroadcastTarget = ""

	Set tQBP = ##class(DGLAB.law.Messages).QBP("C0001", "TAG1")
	Set tRSP = tProc.OnQuery(tQBP)
	Do $$$AssertEquals($Piece($Piece(tRSP, "|", 9), "^", 1, 2), "RSP^K11", "LAB-27 answered by RSP^K11")
	Do $$$AssertTrue(tRSP [ "|OK", "LAB-27 container with work orders")

	Set tUnknown = tProc.OnQuery(##class(DGLAB.law.Messages).QBP("UNKNOWN1", "TAG2"))
	Do $$$AssertTrue(tUnknown [ "|NF", "LAB-27 unknown container answers NF")

	Set tORL = tProc.OnBroadcast(##class(DGLAB.law.Messages).OML("C0001"))
	Do $$$AssertEquals($Piece($Piece(tORL, "|", 9), "^", 1, 2), "ORL^O34", "LAB-28 answered by ORL^O34")

	Set tACK = tProc.OnStatusChange(##class(DGLAB.law.Messages).OUL("C0001", , , $ListBuild(143, "4.1", 102)))
	Do $$$AssertEquals($Piece($Piece(tACK, "|", 9), "^", 1), "ACK", "LAB-29 answered by ACK")
}

}
