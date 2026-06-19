Class DGLAB.transfo.IHEPAM.seances Extends Ens.DataTransformDTL [ DependsOn = EnsLib.HL7.Message ]
{

Parameter GENERATEEMPTYSEGMENTS = 0;

Parameter IGNOREMISSINGSOURCE = 1;

Parameter REPORTERRORS = 1;

Parameter TREATEMPTYREPEATINGFIELDASNULL = 0;

XData DTL [ XMLNamespace = "http://www.intersystems.com/dtl" ]
{
<transform sourceClass='EnsLib.HL7.Message' targetClass='EnsLib.HL7.Message' sourceDocType='HL7v25IHE:ADT_AXX' targetDocType='HL7v25IHE:ADT_AXX' create='copy' language='objectscript' >
<annotation>traitement des séjours à séances : si PV1-51=V (visite) on ignore les dates d&#39;admission/sortie (PV1-44/45) et donc l&#39;ouverture/fermeture/annulation de séjour ; si PV1-51=A (compte) le message est traité normalement (copie)</annotation>
<if condition='source.{PV1:51}="V"' >
<annotation>Niveau visite (séance) : ignorer ouverture, fermeture et annulation de séjour</annotation>
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
