Class IRISAPP.transfo.sqltofhir.MedicationRequest Extends Ens.DataTransformDTL [ DependsOn = (msg.response.medication, HS.FHIR.DTL.vR4.Model.Resource.MedicationRequest) ]
{

Parameter GENERATEEMPTYSEGMENTS = 0;

Parameter IGNOREMISSINGSOURCE = 1;

Parameter REPORTERRORS = 1;

Parameter TREATEMPTYREPEATINGFIELDASNULL = 0;

XData DTL [ XMLNamespace = "http://www.intersystems.com/dtl" ]
{
<transform sourceClass='msg.response.medication' targetClass='HS.FHIR.DTL.vR4.Model.Resource.MedicationRequest' create='new' language='objectscript' >
<assign value='source.id' property='target.id' action='set' />
<assign value='source.status' property='target.status' action='set' />
<assign value='source.intent' property='target.intent' action='set' />
<assign value='source."subject_display"' property='target.subject.display' action='set' />
<assign value='source."dispense_quantity_value"' property='target.dispenseRequest.quantity.value' action='set' />
<assign value='source."dispense_quantity_unit"' property='target.dispenseRequest.quantity.unit' action='set' />
<assign value='source."dispense_number_of_repeats_allowed"' property='target.dispenseRequest.numberOfRepeatsAllowed' action='set' />
<assign value='source."requester_display"' property='target.requester.display' action='set' />
<assign value='source."dosage_text"' property='target.dosageInstruction.(1).text' action='set' />
<assign value='source."dosage_route_display"' property='target.dosageInstruction.(1).route.text' action='set' />
<assign value='source."dosage_dose_value"' property='target.dosageInstruction.(1).doseAndRate.(1).doseQuantity.value' action='set' />
<assign value='source."dosage_dose_unit"' property='target.dosageInstruction.(1).doseAndRate.(1).doseQuantity.unit' action='set' />
<assign value='##class(IRISAPP.transfo.sqltofhir.Util).ToFHIRDateTime(source."authored_on")' property='target.authoredOn' action='set' />
<assign value='source."medication_concept_display"' property='target.medicationCodeableConcept.text' action='set' />
<assign value='source."medication_concept_system"' property='target.medicationCodeableConcept.coding.(1).system' action='set' />
<assign value='source."medication_concept_code"' property='target.medicationCodeableConcept.coding.(1).code' action='set' />
<assign value='"generated"' property='target.text.status' action='set' />
<assign value='"&lt;div xmlns=""http://www.w3.org/1999/xhtml""&gt;MedicationRequest "_source.id_"&lt;/div&gt;"' property='target.text.div' action='set' />
</transform>
}

}
