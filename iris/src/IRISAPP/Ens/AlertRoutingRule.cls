/// 
Class IRISAPP.Ens.AlertRoutingRule Extends Ens.Rule.Definition
{

Parameter RuleAssistClass = "EnsLib.MsgRouter.RuleAssist";

XData RuleDefinition [ XMLNamespace = "http://www.intersystems.com/rule" ]
{
<ruleDefinition alias="" context="EnsLib.MsgRouter.RoutingEngine" production="IRISAPP.production">
<ruleSet name="" effectiveBegin="" effectiveEnd="">
<rule name="Send ALL ALERTS to Loki" disabled="false">
<constraint name="source" value=""></constraint>
<when condition="1" comment="">
<send transform="" target="Message Log to Loki - Grafana"></send>
</when>
</rule>
<rule name="planning astreintes">
<constraint name="msgClass" value="Ens.AlertRequest"></constraint>
<when condition="Document.AlertText[&quot;error&quot;" comment="">
<send transform="" target=",planningastreintes"></send>
</when>
</rule>
<rule name="HL7 v2 messages" disabled="false">
<constraint name="source" value="HL7v2 router"></constraint>
<when condition="1" comment="">
<send transform="" target="Alerte Email"></send>
</when>
</rule>
<rule name="NO FIRST NAME" disabled="false">
<constraint name="source" value="validate"></constraint>
<when condition="1" comment="">
<send transform="" target=",planningastreintes"></send>
</when>
</rule>
</ruleSet>
</ruleDefinition>
}

}
