Class msg.response.bundle Extends (Ens.Response, %JSON.Adaptor)
{

Property patient As msg.response.patient;

Property medications As list Of msg.response.medication;

Property json As %String(MAXLEN = "");

Storage Default
{
<Data name="bundleDefaultData">
<Subscript>"bundle"</Subscript>
<Value name="1">
<Value>patient</Value>
</Value>
<Value name="2">
<Value>medications</Value>
</Value>
<Value name="3">
<Value>json</Value>
</Value>
</Data>
<DefaultData>bundleDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
