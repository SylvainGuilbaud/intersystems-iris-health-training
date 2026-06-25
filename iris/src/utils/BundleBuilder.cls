Class utils.BundleBuilder
{

ClassMethod BuildBundle(patient As msg.response.patient, medications As Ens.StreamContainer) As msg.response.bundle [ Language = python ]
{
import iris
bundle = iris.cls("msg.response.bundle")._New()
bundle.patient = patient
medicationsJSON = ""
while not medications.Stream.AtEnd:
    medicationsJSON += medications.Stream.Read()

root = iris.cls("%DynamicObject")._FromJSON(medicationsJSON)

#Parcours des clés "1","2","3",... (DynamicObject -> iterator)
it = root._GetIterator()
n = iris.ref()       # output ref (clé)
node = iris.ref()    # output ref (valeur)

while (it._GetNext(n, node)):
    key = n.value
    presc = node.value   # <- la prescription (%DynamicObject)

    # Sérialisation JSON du DynamicObject
    json_value = presc._ToJSON()

    # Ecriture dans la globale ^TRACE("node", key)
    #; trace = iris.gref("^TRACE") 
    #; trace[key] = json_value
    
    med = iris.cls("msg.response.medication")._New()
    med.id     = presc._Get("id")
    med.status = presc._Get("status")
    med.intent = presc._Get("intent")

    med.medication_concept_system  = presc._Get("medication_concept_system")
    med.medication_concept_code    = presc._Get("medication_concept_code")  
    med.medication_concept_display = presc._Get("medication_concept_display")

    med.subject_reference = presc._Get("subject_reference")
    med.subject_display   = presc._Get("subject_display")    
    med.authored_on       = presc._Get("authored_on")    
    med.requester_display = presc._Get("requester_display")

    med.dosage_text          = presc._Get("dosage_text")
    med.dosage_route_display = presc._Get("dosage_route_display")
    med.dosage_dose_value    = presc._Get("dosage_dose_value")     
    med.dosage_dose_unit     = presc._Get("dosage_dose_unit")

    med.dispense_quantity_value = presc._Get("dispense_quantity_value")
    med.dispense_quantity_unit  = presc._Get("dispense_quantity_unit")
    med.dispense_number_of_repeats_allowed = presc._Get("dispense_number_of_repeats_allowed")

    bundle.medications.Insert(med)
return bundle
}

ClassMethod BuildBundleOS(patient As msg.response.patient, medications As Ens.StreamContainer) As msg.response.bundle
{
    Set bundle = ##class(msg.response.bundle).%New()
    Set bundle.patient = patient
    Set medicationsJSON = ""
    while 'medications.Stream.AtEnd {
         Set medicationsJSON = medicationsJSON _ medications.Stream.Read()
    }

    Set root = ##class(%DynamicObject).%FromJSON(medicationsJSON)

    // Parcours des clés "1","2","3",... (DynamicObject -> iterator)
    Set it = root.%GetIterator()
    While it.%GetNext(.n, .node) {

        // node = %DynamicObject (la prescription)
        Set med = ##class(msg.response.medication).%New()

        // Affectations directes (pas de %Set)
        Set med.id     = node.id
        Set med.status = node.status
        Set med.intent = node.intent

        Set med."medication_concept_system"  = node."medication_concept_system"
        Set med."medication_concept_code"    = node."medication_concept_code"
        Set med."medication_concept_display" = node."medication_concept_display"

        Set med."subject_reference" = node."subject_reference"
        Set med."subject_display"   = node."subject_display"
        Set med."authored_on"       = node."authored_on"
        Set med."requester_display" = node."requester_display"

        Set med."dosage_text"          = node."dosage_text"
        Set med."dosage_route_display" = node."dosage_route_display"
        Set med."dosage_dose_value"    = node."dosage_dose_value"
        Set med."dosage_dose_unit"     = node."dosage_dose_unit"

        Set med."dispense_quantity_value" = node."dispense_quantity_value"
        Set med."dispense_quantity_unit"  = node."dispense_quantity_unit"
        Set med."dispense_number_of_repeats_allowed" = node."dispense_number_of_repeats_allowed"

        Do bundle.medications.Insert(med)

    }

    return bundle
}

}
