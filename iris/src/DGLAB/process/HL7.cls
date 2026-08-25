/// 
Class DGLAB.process.HL7 Extends Ens.BusinessProcessBPL
{

/// BPL Definition
XData BPL [ XMLNamespace = "http://www.intersystems.com/bpl" ]
{
<process language='objectscript' request='msg.request.patient' response='msg.response.patient' height='2000' width='2000' >
<context>
<property name='patient' type='msg.response.patient' instantiate='0' deletewithcontext='0' />
<property name='medication' type='msg.response.medication' instantiate='0' deletewithcontext='0' />
</context>
<sequence xend='200' yend='600' >
<flow xpos='200' ypos='250' xend='200' yend='500' >
<sequence >
<call name='get patient data' target='get Patient' async='0' xpos='200' ypos='400' >
<annotation><![CDATA[retrieve patient data 
from Technidata reference]]></annotation>
<request type='msg.request.patient' >
<assign property="callrequest" value="request" action="set" />
</request>
<response type='msg.response.patient' >
<assign property="context.patient" value="callresponse" action="set" />
<assign property="response" value="context.patient" action="set" />
</response>
</call>
</sequence>
<sequence >
<call name='get medication data' target='get Medication' async='0' xpos='470' ypos='400' >
<annotation><![CDATA[retrieve medication data 
from Technidata reference]]></annotation>
<request type='msg.request.medication' >
<assign property="callrequest.patient" value="request.id" action="set" />
</request>
<response type='msg.response.medication' >
<assign property="context.medication" value="callresponse" action="set" />
</response>
</call>
</sequence>
</flow>
</sequence>
</process>
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}
