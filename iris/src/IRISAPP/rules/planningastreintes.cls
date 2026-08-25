/// 
Class IRISAPP.rules.planningastreintes Extends Ens.Rule.Definition
{

Parameter RuleAssistClass = "EnsLib.MsgRouter.RuleAssist";

XData RuleDefinition [ XMLNamespace = "http://www.intersystems.com/rule" ]
{
<ruleDefinition alias="planning astreintes" context="EnsLib.MsgRouter.RoutingEngine" production="IRISAPP.production">
<ruleSet name="" effectiveBegin="" effectiveEnd="">
<rule name="samedi, dimanche ou jour férié">
<when condition="((WeekEnd())=1)||((isPublicHoliday())=1)" comment="">
<send transform="" target="Alertes Week-End"></send>
<return></return>
</when>
</rule>
<rule name="heures ouvrables" disabled="false">
<when condition="((Heure())&gt;=(08))&amp;&amp;((Heure())&lt;(20))" comment="">
<send transform="" target="Alertes de jour"></send>
<return></return>
</when>
</rule>
<rule name="heures de nuit" disabled="false">
<when condition="((Heure())&gt;=(20))||((Heure())&lt;(8))" comment="">
<send transform="" target="Alertes de nuit"></send>
<return></return>
</when>
</rule>
</ruleSet>
</ruleDefinition>
}

}
