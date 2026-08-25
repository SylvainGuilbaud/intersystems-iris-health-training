Class data.patient Extends (%Persistent,%XML.Adaptor, %JSON.Adaptor, %Populate)
{

/// IPP (Identifiant Permanent du Patient) is a unique identifier for a patient in the French healthcare system.
Property IPP As %String (MAXLEN = 20)[Required];

Property lastName As %String (MAXLEN = 250);

Property birthName As %String (MAXLEN = 250);

Property firstName As %String (MAXLEN = 250);

/// Email address validated against a basic pattern (local@domain.tld).
Property email As %String(MAXLEN = 250, PATTERN = "1.(1AN,1""."",1""-"",1""_"")1""@""1.(1AN,1""-"")1"".""1.(1AN,1""-"")", POPSPEC = "String(5)_""@example.com""");

Property mobilePhone As %String (MAXLEN = 20);

Property phone As %String (MAXLEN = 20);

Property otherPhone As %String (MAXLEN = 20);

Property sex As %Integer(DISPLAYLIST = ",M,F,I", VALUELIST = ",1,2,3");

/// Date of birth 
Property DOB As %Date;

Property homeAddress As data.address;

Property nationality As %String(MAXLEN = 50);

/// Place of birth
Property birthPlace As data.address;

/// Social security number
Property SSN As %String(MAXLEN = 20);

/// Identité Nationale de Santé - National Health Identity (INS) is a unique identifier for individuals in the French healthcare system.
Property INS As %String(MAXLEN = 50);

Property status As %String(VALUELIST = ",qualified,unqualified,deleted");

Property createdAt As %TimeStamp [ InitialExpression = {$zdt($horolog, 3)} ];

Property updatedAt As %TimeStamp;

Property isTemporary As %Boolean[InitialExpression = "0"];

Property anonymat As %String;

/// Marital status
Property maritalStatus As %String(MAXLEN=1,VALUELIST = ",C,P,D,V,U,A,M,S");

Property professionalCategory As %String(MAXLEN = 250);

/// Date of death
Property DOD As %Date;

Property createdBy As data.users;

Storage Default
{
<Data name="patientDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>IPP</Value>
</Value>
<Value name="3">
<Value>lastName</Value>
</Value>
<Value name="4">
<Value>birthName</Value>
</Value>
<Value name="5">
<Value>firstName</Value>
</Value>
<Value name="6">
<Value>email</Value>
</Value>
<Value name="7">
<Value>mobilePhone</Value>
</Value>
<Value name="8">
<Value>phone</Value>
</Value>
<Value name="9">
<Value>otherPhone</Value>
</Value>
<Value name="10">
<Value>sex</Value>
</Value>
<Value name="11">
<Value>DOB</Value>
</Value>
<Value name="12">
<Value>homeAddress</Value>
</Value>
<Value name="13">
<Value>nationality</Value>
</Value>
<Value name="14">
<Value>birthPlace</Value>
</Value>
<Value name="15">
<Value>SSN</Value>
</Value>
<Value name="16">
<Value>INS</Value>
</Value>
<Value name="17">
<Value>status</Value>
</Value>
<Value name="18">
<Value>createdAt</Value>
</Value>
<Value name="19">
<Value>updatedAt</Value>
</Value>
<Value name="20">
<Value>isTemporary</Value>
</Value>
<Value name="21">
<Value>anonymat</Value>
</Value>
<Value name="22">
<Value>maritalStatus</Value>
</Value>
<Value name="23">
<Value>professionalCategory</Value>
</Value>
<Value name="24">
<Value>DOD</Value>
</Value>
<Value name="25">
<Value>createdBy</Value>
</Value>
</Data>
<DataLocation>^data.patientD</DataLocation>
<DefaultData>patientDefaultData</DefaultData>
<IdLocation>^data.patientD</IdLocation>
<IndexLocation>^data.patientI</IndexLocation>
<StreamLocation>^data.patientS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
