/// Interop response describing the outcome of a FHIR Patient create/update.
Class training.fhir.msg.PatientResponse Extends Ens.Response
{

/// data.patient id that was processed.
Property PatientId As %String;

/// HTTP status returned by the FHIR server (e.g. 200, 201).
Property HTTPStatus As %String;

/// Logical id of the Patient resource on the FHIR server.
Property ResourceId As %String;

/// Verb actually used (POST or PUT).
Property HTTPMethod As %String;

Storage Default
{
<Data name="PatientResponseDefaultData">
<Subscript>"PatientResponse"</Subscript>
<Value name="1">
<Value>PatientId</Value>
</Value>
<Value name="2">
<Value>HTTPStatus</Value>
</Value>
<Value name="3">
<Value>ResourceId</Value>
</Value>
<Value name="4">
<Value>HTTPMethod</Value>
</Value>
</Data>
<DefaultData>PatientResponseDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
