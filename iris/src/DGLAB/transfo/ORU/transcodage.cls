Class DGLAB.transfo.ORU.transcodage Extends Ens.DataTransformDTL [ DependsOn = EnsLib.HL7.Message ]
{

Parameter GENERATEEMPTYSEGMENTS = 0;

Parameter IGNOREMISSINGSOURCE = 1;

Parameter REPORTERRORS = 1;

Parameter TREATEMPTYREPEATINGFIELDASNULL = 0;

XData DTL [ XMLNamespace = "http://www.intersystems.com/dtl" ]
{
<transform sourceClass='EnsLib.HL7.Message' targetClass='EnsLib.HL7.Message' sourceDocType='2.3:ORU_R01' targetDocType='2.3:ORU_R01' create='copy' language='objectscript' >
<annotation>ORU transmission: title, gender and patient class transcoded via the SAME shared tables as the ADT reception (Titles, Gender, PatientClasses). Demonstrates sharing a transcoding centralized in the IRIS namespace, which cannot be centralized on the DGLab side.</annotation>
<assign value='..Lookup("Titles",source.{PIDgrpgrp(1).PIDgrp.PID:PatientName.prefix})' property='target.{PIDgrpgrp().PIDgrp.PID:PatientName.prefix}' action='set' />
<assign value='..Lookup("Gender",source.{PIDgrpgrp(1).PIDgrp.PID:Sex})' property='target.{PIDgrpgrp(1).PIDgrp.PID:Sex}' action='set' />
</transform>
}

}
