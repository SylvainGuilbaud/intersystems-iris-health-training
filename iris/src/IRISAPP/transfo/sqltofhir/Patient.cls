Class IRISAPP.transfo.sqltofhir.Patient Extends Ens.DataTransformDTL [ DependsOn = (msg.response.patient, HS.FHIR.DTL.vR4.Model.Resource.Patient) ]
{

Parameter GENERATEEMPTYSEGMENTS = 0;

Parameter IGNOREMISSINGSOURCE = 1;

Parameter REPORTERRORS = 1;

Parameter TREATEMPTYREPEATINGFIELDASNULL = 0;

XData DTL [ XMLNamespace = "http://www.intersystems.com/dtl" ]
{
<transform sourceClass='msg.response.patient' targetClass='HS.FHIR.DTL.vR4.Model.Resource.Patient' create='new' language='objectscript' >
<assign value='source.id' property='target.id' action='set' />
<assign value='source."identifier_value"' property='target.identifier.(1).value' action='set' />
<assign value='source."identifier_use"' property='target.identifier.(1).use' action='set' />
<assign value='source."name_use"' property='target.name.(1).use' action='set' />
<assign value='source."name_family"' property='target.name.(1).family' action='set' />
<assign value='source."name_given"' property='target.name.(1).given.(1)' action='set' />
<assign value='source."telecom_system"' property='target.telecom.(1).system' action='set' />
<assign value='source."telecom_value"' property='target.telecom.(1).value' action='set' />
<assign value='source."telecom_use"' property='target.telecom.(1).use' action='set' />
<assign value='source.gender' property='target.gender' action='set' />
<assign value='$zdate(source."birth_date",3)' property='target.birthDate' action='set' />
<assign value='source."address_use"' property='target.address.(1).use' action='set' />
<assign value='source."address_line"' property='target.address.(1).line.(1)' action='set' />
<assign value='source."address_city"' property='target.address.(1).city' action='set' />
<assign value='source."address_postal_code"' property='target.address.(1).postalCode' action='set' />
<assign value='source."address_country"' property='target.address.(1).country' action='set' />
<assign value='"generated"' property='target.text.status' action='set' />
<assign value='"&lt;div xmlns=""http://www.w3.org/1999/xhtml""&gt;Patient "_source.id_"&lt;/div&gt;"' property='target.text.div' action='set' />
</transform>
}

}
