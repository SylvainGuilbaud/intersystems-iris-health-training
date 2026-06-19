/// 
Class DGLAB.router.HL7 Extends Ens.Rule.Definition
{

Parameter RuleAssistClass = "EnsLib.HL7.MsgRouter.RuleAssist";

XData RuleDefinition [ XMLNamespace = "http://www.intersystems.com/rule" ]
{
<ruleDefinition alias="" context="EnsLib.HL7.MsgRouter.RoutingEngine" production="DGLABPKG.FoundationProduction">
<ruleSet name="" effectiveBegin="" effectiveEnd="">
<rule name="ORU">
<constraint name="source" value=""></constraint>
<constraint name="docCategory" value="2.3"></constraint>
<constraint name="docName" value="ORU_R01"></constraint>
<when condition="1" comment="">
<foreach propertypath="HL7.{PIDgrpgrp().ORCgrp().OBXgrp().OBX}">
<when condition="(Segment.{ObservationIdentifier.identifier}=&quot;PDFREPORT&quot;)&amp;&amp;(Segment.{ValueType}=&quot;ED&quot;)" comment="">
<send transform="" target="to EMR - FILE"></send>
<trace value="&quot;Encapsulted Data&quot;"></trace>
</when>
<when condition="(Segment.{ObservationIdentifier.identifier}=&quot;PDFREPORT&quot;)&amp;&amp;(Segment.{ValueType}=&quot;RP&quot;)" comment="">
<send transform="" target="to EMR - FILE"></send>
<trace value="&quot;Reference Pointer&quot;"></trace>
</when>
<otherwise>
<trace value="&quot;no action&quot;"></trace>
</otherwise>
</foreach>
</when>
</rule>
</ruleSet>
</ruleDefinition>
}

}
