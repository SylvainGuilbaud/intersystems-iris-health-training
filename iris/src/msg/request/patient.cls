Class msg.request.patient Extends Ens.Request
{

Property id As %String;

Property format As %String [ InitialExpression = "sql" ];

Storage Default
{
<Data name="patientDefaultData">
<Subscript>"patient"</Subscript>
<Value name="1">
<Value>id</Value>
</Value>
<Value name="2">
<Value>format</Value>
</Value>
</Data>
<DefaultData>patientDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
