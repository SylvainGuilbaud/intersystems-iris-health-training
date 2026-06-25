Class IRISAPP.transfo.HL7ADT Extends Ens.DataTransformDTL [ DependsOn = EnsLib.HL7.Message ]
{

Parameter GENERATEEMPTYSEGMENTS = 0;

Parameter IGNOREMISSINGSOURCE = 1;

Parameter REPORTERRORS = 1;

Parameter TREATEMPTYREPEATINGFIELDASNULL = 0;

XData DTL [ XMLNamespace = "http://www.intersystems.com/dtl" ]
{
<transform sourceClass='EnsLib.HL7.Message' targetClass='EnsLib.HL7.Message' sourceDocType='HL7v25IHE:ADT_AXX' targetDocType='nonIHE:ADT_XXX' create='new' language='objectscript' >
<assign value='source.{MSH}' property='target.{MSH}' action='set' />
<assign value='"A01"' property='target.{MSH:MessageType.triggerevent}' action='set' />
<assign value='"2.03"' property='target.{MSH:VersionID}' action='set' />
<assign value='source.{EVN}' property='target.{EVN}' action='set' />
<assign value='source.{PID}' property='target.{PID}' action='set' />
<if condition='source.{PID:AdministrativeSex}="F"' >
<true>
<assign value='"Commentaire associé à la patiente "_source.{PID:PatientName().GivenName}_" "_source.{PID:PatientName().FamilyName.Surname}' property='target.{NTE:Comment(1)}' action='set' />
</true>
<false>
<assign value='"Commentaire associé au patient "_source.{PID:PatientName().GivenName}_" "_source.{PID:PatientName().FamilyName.Surname}' property='target.{NTE:Comment(1)}' action='set' />
</false>
</if>
<assign value='source.{PV1}' property='target.{PV1}' action='set' />
</transform>
}

}
