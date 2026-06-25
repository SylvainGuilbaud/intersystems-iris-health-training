Class msg.request.medication Extends Ens.Request
{

Property patient As %String;

Storage Default
{
<Data name="medicationDefaultData">
<Subscript>"medication"</Subscript>
<Value name="1">
<Value>patient_reference</Value>
</Value>
<Value name="2">
<Value>patient</Value>
</Value>
</Data>
<DefaultData>medicationDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
