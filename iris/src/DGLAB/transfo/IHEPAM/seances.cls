Class DGLAB.transfo.IHEPAM.seances Extends Ens.DataTransformDTL [ DependsOn = EnsLib.HL7.Message ]
{

Parameter GENERATEEMPTYSEGMENTS = 0;

Parameter IGNOREMISSINGSOURCE = 1;

Parameter REPORTERRORS = 1;

Parameter TREATEMPTYREPEATINGFIELDASNULL = 0;

XData DTL [ XMLNamespace = "http://www.intersystems.com/dtl" ]
{
<transform sourceClass='EnsLib.HL7.Message' targetClass='EnsLib.HL7.Message' sourceDocType='HL7v25IHE:ADT_AXX' targetDocType='HL7v25IHE:ADT_AXX' create='copy' language='objectscript' >
<annotation>Session-stay handling: if PV1-51=V (visit) the admission/discharge dates (PV1-44/45) are ignored, hence the stay opening/closing/cancellation is ignored; if PV1-51=A (account) the message is handled normally (copy). Title, gender and patient class are transcoded via the shared tables (Titles, Gender, PatientClasses).</annotation>
<assign value='..Lookup("Titles",source.{PID:5.5},source.{PID:5.5})' property='target.{PID:5.5}' action='set' >
<annotation>Title (PID-5.5) normalized via the SHARED Titles table (common to ADT/ORU)</annotation>
</assign>
<assign value='..Lookup("Gender",source.{PID:8},source.{PID:8})' property='target.{PID:8}' action='set' >
<annotation>Gender normalized via the shared Gender table</annotation>
</assign>
<if condition='source.{PV1:51}="V"' >
<annotation>Visit level (session): ignore stay opening, closing and cancellation</annotation>
<true>
<assign value='""' property='target.{PV1:44}' action='set' >
<annotation>Ignore PV1-44 Admission Date/Time</annotation>
</assign>
<assign value='""' property='target.{PV1:45}' action='set' >
<annotation>Ignore PV1-45 Discharge Date/Time</annotation>
</assign>
</true>
</if>
</transform>
}

}
