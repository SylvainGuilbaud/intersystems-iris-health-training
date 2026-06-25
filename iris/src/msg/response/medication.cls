Class msg.response.medication Extends (Ens.Response, %JSON.Adaptor)
{

Property id As %String(MAXLEN = "");

Property status As %String(MAXLEN = "");

Property intent As %String(MAXLEN = "");

Property "medication_concept_system" As %String(MAXLEN = "");

Property "medication_concept_code" As %String(MAXLEN = "");

Property "medication_concept_display" As %String(MAXLEN = "");

Property "subject_reference" As %String(MAXLEN = "");

Property "subject_display" As %String(MAXLEN = "");

Property "authored_on" As %String(MAXLEN = "");

Property "requester_display" As %String(MAXLEN = "");

Property "dosage_text" As %String(MAXLEN = "");

Property "dosage_route_display" As %String(MAXLEN = "");

Property "dosage_dose_value" As %String(MAXLEN = "");

Property "dosage_dose_unit" As %String(MAXLEN = "");

Property "dispense_quantity_value" As %String(MAXLEN = "");

Property "dispense_quantity_unit" As %String(MAXLEN = "");

Property "dispense_number_of_repeats_allowed" As %String(MAXLEN = "");

Storage Default
{
<Data name="medicationDefaultData">
<Subscript>"medication"</Subscript>
<Value name="1">
<Value>id</Value>
</Value>
<Value name="2">
<Value>status</Value>
</Value>
<Value name="3">
<Value>intent</Value>
</Value>
<Value name="4">
<Value>medication_concept_system</Value>
</Value>
<Value name="5">
<Value>medication_concept_code</Value>
</Value>
<Value name="6">
<Value>medication_concept_display</Value>
</Value>
<Value name="7">
<Value>subject_reference</Value>
</Value>
<Value name="8">
<Value>subject_display</Value>
</Value>
<Value name="9">
<Value>authored_on</Value>
</Value>
<Value name="10">
<Value>requester_display</Value>
</Value>
<Value name="11">
<Value>dosage_text</Value>
</Value>
<Value name="12">
<Value>dosage_route_display</Value>
</Value>
<Value name="13">
<Value>dosage_dose_value</Value>
</Value>
<Value name="14">
<Value>dosage_dose_unit</Value>
</Value>
<Value name="15">
<Value>dispense_quantity_value</Value>
</Value>
<Value name="16">
<Value>dispense_quantity_unit</Value>
</Value>
<Value name="17">
<Value>dispense_number_of_repeats_allowed</Value>
</Value>
</Data>
<DefaultData>medicationDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
