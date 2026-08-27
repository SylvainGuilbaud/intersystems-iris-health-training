/// Interop request carrying either a data.patient id or a FHIR resource stream.
Class training.fhir.msg.PatientRequest Extends Ens.Request
{

/// Id of the data.patient row to convert and send.
Property PatientId As %String;

/// Id of the QuickStream containing a FHIR Patient JSON body.
Property ResourceStreamId As %String;

/// Optional override of the HTTP verb. Empty = use the operation/process default.
Property HTTPMethod As %String(VALUELIST = ",POST,PUT,DELETE");

Storage Default
{
<Data name="PatientRequestDefaultData">
<Subscript>"PatientRequest"</Subscript>
<Value name="1">
<Value>PatientId</Value>
</Value>
<Value name="2">
<Value>ResourceStreamId</Value>
</Value>
<Value name="3">
<Value>HTTPMethod</Value>
</Value>
</Data>
<DefaultData>PatientRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
