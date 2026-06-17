/// 
Class DGLAB.router.HL7 Extends Ens.Rule.Definition
{

Parameter RuleAssistClass = "EnsLib.HL7.MsgRouter.RuleAssist";

XData RuleDefinition [ XMLNamespace = "http://www.intersystems.com/rule" ]
{
<ruleDefinition alias="" context="EnsLib.HL7.MsgRouter.RoutingEngine" production="DGLABPKG.FoundationProduction">
<ruleSet name="" effectiveBegin="" effectiveEnd="">
<rule name="ORU">
<constraint name="source" value="from DGLAB"></constraint>
<constraint name="docCategory" value="2.3"></constraint>
<constraint name="docName" value="ORU_R01"></constraint>
<when condition="1" comment="">
<send transform="" target="to EMR - FILE"></send>
</when>
</rule>
</ruleSet>
</ruleDefinition>
}

}
