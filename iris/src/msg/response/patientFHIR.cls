Class msg.response.patientFHIR Extends Ens.Response
{

Property id As %String;

Property "last_name" As %String [ SqlFieldName = last_name ];

Property "first_name" As %String [ SqlFieldName = first_name ];

Property fhir As %String(MAXLEN = "");

Storage Default
{
<Data name="patientFHIRDefaultData">
<Subscript>"patientFHIR"</Subscript>
<Value name="1">
<Value>id</Value>
</Value>
<Value name="2">
<Value>last_name</Value>
</Value>
<Value name="3">
<Value>first_name</Value>
</Value>
<Value name="4">
<Value>fhir</Value>
</Value>
</Data>
<DefaultData>patientFHIRDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
