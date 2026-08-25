Class data.users Extends (%Persistent,%XML.Adaptor, %JSON.Adaptor, %Populate)
{
Property matricule As %String(MAXLEN = 50);
Property nom As %String(MAXLEN = 250);
Property prenom As %String(MAXLEN = 250);
Property dob As %Date;
Property sexe As %String(MAXLEN = 1);
Property mail As %String(MAXLEN = 250);
Property login As %String(MAXLEN = 50);
Property titre As %String(MAXLEN = 50);
Property UF As %String(MAXLEN = 50);
Property UFLibelle As %String(MAXLEN = 250);
Property rpps As %String(MAXLEN = 50);
Property dect As %String(MAXLEN = 50);
Property mobile As %String(MAXLEN = 20);
Property telephoneNumber As %String(MAXLEN = 20);
Property pm As %String(MAXLEN = 50);
Property imm As %String(MAXLEN = 50);
Property active As %Boolean[InitialExpression = "1"];

Storage Default
{
<Data name="usersDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>matricule</Value>
</Value>
<Value name="3">
<Value>nom</Value>
</Value>
<Value name="4">
<Value>prenom</Value>
</Value>
<Value name="5">
<Value>dob</Value>
</Value>
<Value name="6">
<Value>sexe</Value>
</Value>
<Value name="7">
<Value>mail</Value>
</Value>
<Value name="8">
<Value>login</Value>
</Value>
<Value name="9">
<Value>titre</Value>
</Value>
<Value name="10">
<Value>UF</Value>
</Value>
<Value name="11">
<Value>UFLibelle</Value>
</Value>
<Value name="12">
<Value>rpps</Value>
</Value>
<Value name="13">
<Value>dect</Value>
</Value>
<Value name="14">
<Value>mobile</Value>
</Value>
<Value name="15">
<Value>telephoneNumber</Value>
</Value>
<Value name="16">
<Value>pm</Value>
</Value>
<Value name="17">
<Value>imm</Value>
</Value>
<Value name="18">
<Value>active</Value>
</Value>
</Data>
<DataLocation>^data.usersD</DataLocation>
<DefaultData>usersDefaultData</DefaultData>
<IdLocation>^data.usersD</IdLocation>
<IndexLocation>^data.usersI</IndexLocation>
<StreamLocation>^data.usersS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
