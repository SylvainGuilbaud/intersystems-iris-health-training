/// 
Class DAY2.rules.fromPAM Extends Ens.Rule.Definition
{

Parameter RuleAssistClass = "EnsLib.HL7.MsgRouter.RuleAssist";

XData RuleDefinition [ XMLNamespace = "http://www.intersystems.com/rule" ]
{
<ruleDefinition alias="DAY2.rules.from PAM" context="EnsLib.HL7.MsgRouter.RoutingEngine" production="DAY2PKG.FoundationProduction">
<ruleSet name="" effectiveBegin="" effectiveEnd="">
<rule name="">
<constraint name="source" value="from DGLAB RESULTS"></constraint>
<constraint name="docCategory" value="2.3"></constraint>
<constraint name="docName" value="ORM_O01"></constraint>
<when condition="1" comment="">
<send transform="" target="to EMR"></send>
</when>
</rule>
</ruleSet>
</ruleDefinition>
}

}
