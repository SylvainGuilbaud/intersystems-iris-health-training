Class msg.response.patient Extends (Ens.Response, %JSON.Adaptor)
{

Property id As %String;

Property "identifier_value" As %String(MAXLEN = "");

Property "identifier_use" As %String(MAXLEN = "");

Property "name_use" As %String(MAXLEN = "");

Property "name_family" As %String(MAXLEN = "");

Property "name_given" As %String(MAXLEN = "");

Property "name_text" As %String(MAXLEN = "");

Property "telecom_system" As %String(MAXLEN = "");

Property "telecom_value" As %String(MAXLEN = "");

Property "telecom_use" As %String(MAXLEN = "");

Property gender As %String(MAXLEN = "");

Property "birth_date" As %Date;

Property "address_use" As %String(MAXLEN = "");

Property "address_line" As %String(MAXLEN = "");

Property "address_city" As %String(MAXLEN = "");

Property "address_postal_code" As %String(MAXLEN = "");

Property "address_country" As %String(MAXLEN = "");

Storage Default
{
<Data name="patientDefaultData">
<Subscript>"patient"</Subscript>
<Value name="1">
<Value>id</Value>
</Value>
<Value name="2">
<Value>identifier_value</Value>
</Value>
<Value name="3">
<Value>identifier_use</Value>
</Value>
<Value name="4">
<Value>name_use</Value>
</Value>
<Value name="5">
<Value>name_family</Value>
</Value>
<Value name="6">
<Value>name_given</Value>
</Value>
<Value name="7">
<Value>name_text</Value>
</Value>
<Value name="8">
<Value>telecom_system</Value>
</Value>
<Value name="9">
<Value>telecom_value</Value>
</Value>
<Value name="10">
<Value>telecom_use</Value>
</Value>
<Value name="11">
<Value>gender</Value>
</Value>
<Value name="12">
<Value>birth_date</Value>
</Value>
<Value name="13">
<Value>address_use</Value>
</Value>
<Value name="14">
<Value>address_line</Value>
</Value>
<Value name="15">
<Value>address_city</Value>
</Value>
<Value name="16">
<Value>address_postal_code</Value>
</Value>
<Value name="17">
<Value>address_country</Value>
</Value>
</Data>
<DefaultData>patientDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
