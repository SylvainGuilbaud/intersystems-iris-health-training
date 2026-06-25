Class IRISAPP.transfo.sqltofhir.Bundle Extends Ens.DataTransformDTL [ DependsOn = (msg.response.bundle, HS.FHIR.DTL.vR4.Model.Resource.Bundle) ]
{

Parameter GENERATEEMPTYSEGMENTS = 0;

Parameter IGNOREMISSINGSOURCE = 1;

Parameter REPORTERRORS = 1;

Parameter TREATEMPTYREPEATINGFIELDASNULL = 0;

XData DTL [ XMLNamespace = "http://www.intersystems.com/dtl" ]
{
<transform sourceClass='msg.response.bundle' targetClass='HS.FHIR.DTL.vR4.Model.Resource.Bundle' create='new' language='objectscript' >

  <assign value='"collection"' property='target.type' action='set' />

  <!-- We'll reuse this everywhere -->
  <assign value='##class(IRISAPP.transfo.sqltofhir.Util).UrnUuid("patient",source.patient.id)'
          property='patientFU' action='set' />

  <assign value='1' property='key' action='set' />

  <!-- Patient entry -->
  <assign value='patientFU' property='target.entry.(key).fullUrl' action='set' />
  <subtransform class='IRISAPP.transfo.sqltofhir.Patient'
               targetObj='target.entry.(key).resource'
               sourceObj='source.patient' />

  <!-- MedicationRequest entries -->
  <foreach property='source.medications()' key='k1' >
    <assign value='key+1' property='key' action='set' />

    <assign value='##class(IRISAPP.transfo.sqltofhir.Util).UrnUuid("mreq",source.medications.(k1).id)'
            property='target.entry.(key).fullUrl' action='set' />

    <subtransform class='IRISAPP.transfo.sqltofhir.MedicationRequest'
                 targetObj='target.entry.(key).resource'
                 sourceObj='source.medications.(k1)' />

    <!-- Force subject.reference to match Patient fullUrl (urn:uuid:...) -->
    <assign value='patientFU'
            property='target.entry.(key).resource.subject.reference' action='set' />
  </foreach>

</transform>
}

}
