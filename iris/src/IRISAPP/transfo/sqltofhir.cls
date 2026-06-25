Class IRISAPP.transfo.sqltofhir Extends Ens.DataTransformDTL [ DependsOn = (msg.response.patient, HS.FHIR.DTL.vR4.Model.Resource.Patient) ]
{

Parameter GENERATEEMPTYSEGMENTS = 0;

Parameter IGNOREMISSINGSOURCE = 1;

Parameter REPORTERRORS = 1;

Parameter TREATEMPTYREPEATINGFIELDASNULL = 0;

XData DTL [ XMLNamespace = "http://www.intersystems.com/dtl" ]
{
<transform sourceClass='msg.response.patient' targetClass='HS.FHIR.DTL.vR4.Model.Resource.Patient' create='new' language='objectscript' >
<assign value='source.id' property='target.id' action='set' />
<assign value='source."last_name"' property='target.name.(1).family' action='set' />
<assign value='source."first_name"' property='target.name.(1).given.(1)' action='set' />
</transform>
}

}
