Class common.transfo.HL7v2ORUtoEMR Extends Ens.DataTransformDTL [ DependsOn = EnsLib.HL7.Message ]
{

Parameter GENERATEEMPTYSEGMENTS = 0;

Parameter IGNOREMISSINGSOURCE = 1;

Parameter REPORTERRORS = 1;

Parameter TREATEMPTYREPEATINGFIELDASNULL = 0;

XData DTL [ XMLNamespace = "http://www.intersystems.com/dtl" ]
{
<transform sourceClass='EnsLib.HL7.Message' targetClass='EnsLib.HL7.Message' sourceDocType='2.3:ORU_R01' targetDocType='2.3:ORU_R01' create='new' language='objectscript' >
<assign value='source' property='target' action='set' />
<if condition='source.{MSH:SendingFacility}="LAB"' >
<true>
<assign value='"."' property='target.{DSC:ContinuationPointer}' action='set' />
</true>
</if>
<foreach property='source.{PIDgrpgrp()}' key='k1' >
<assign value='..Lookup("Titles",source.{PIDgrpgrp(k1).PIDgrp.PID:PatientName.prefix})' property='target.{PIDgrpgrp(k1).PIDgrp.PID:PatientName.prefix}' action='set' />
</foreach>
</transform>
}

}
