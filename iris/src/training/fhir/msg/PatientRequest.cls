/// Interop request carrying a data.patient id to push to the FHIR server.
Class training.fhir.msg.PatientRequest Extends Ens.Request
{

/// Id of the data.patient row to convert and send.
Property PatientId As %String [ Required ];

/// Optional override of the HTTP verb (POST or PUT). Empty = use the operation/process default.
Property HTTPMethod As %String(VALUELIST = ",POST,PUT");

Storage Default
{
<Data name="PatientRequestDefaultData">
<Subscript>"PatientRequest"</Subscript>
<Value name="1">
<Value>PatientId</Value>
</Value>
<Value name="2">
<Value>HTTPMethod</Value>
</Value>
</Data>
<DefaultData>PatientRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
