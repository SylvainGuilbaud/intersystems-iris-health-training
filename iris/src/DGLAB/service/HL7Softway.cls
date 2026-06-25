Class TECHNIDATA.service.HL7Softway Extends EnsLib.HL7.Service.TCPService
{

Property HL7CustomACK As %String (VALUELIST = ",Non-Standard,HJ,HH,AA,AE,AR") [InitialExpression = "AA"];
Property HL7CustomXYZ As %String (VALUELIST = ",Non-SSSS,HJ,HH,AA,AE,AR") [InitialExpression = "AA"];

Parameter SETTINGS = "HL7CustomACK:Technidata,HL7CustomXYZ:Technidata";


}
