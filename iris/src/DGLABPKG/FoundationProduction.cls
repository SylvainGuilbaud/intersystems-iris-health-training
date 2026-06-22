Class DGLABPKG.FoundationProduction Extends Ens.Production [ Not ProcedureBlock ]
{

XData ProductionDefinition
{
<Production Name="DGLABPKG.FoundationProduction" TestingEnabled="true" LogGeneralTraceEvents="true">
  <Description></Description>
  <ActorPoolSize>1</ActorPoolSize>
  <Setting Target="Adapter" Name="ShutdownTimeout">5</Setting>
  <Setting Target="Adapter" Name="UpdateTimeout">5</Setting>
  <Item Name="HL7" Category="" ClassName="EnsLib.HL7.MsgRouter.RoutingEngine" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true" Schedule="">
    <Setting Target="Host" Name="BusinessRuleName">DGLAB.router.HL7</Setting>
  </Item>
  <Item Name="to EMR - FILE" Category="" ClassName="EnsLib.HL7.Operation.FileOperation" PoolSize="1" Enabled="false" Foreground="false" Comment="" LogTraceEvents="true" Schedule="">
    <Setting Target="Host" Name="Filename">from_DGLAB_to_DPI%Q.hl7</Setting>
  </Item>
  <Item Name="LAB RESULT from DGLAB - MLLP" Category="" ClassName="EnsLib.HL7.Service.TCPService" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true" Schedule="">
    <Setting Target="Host" Name="TargetConfigNames">HL7</Setting>
    <Setting Target="Adapter" Name="JobPerConnection">1</Setting>
    <Setting Target="Host" Name="AddNackERR">1</Setting>
    <Setting Target="Host" Name="NackErrorCode">AllE</Setting>
    <Setting Target="Host" Name="PreACKTCPClear">1</Setting>
    <Setting Target="Host" Name="SaveReplies">All</Setting>
  </Item>
  <Item Name="LAB RESULT from DGLAB - FILE" Category="" ClassName="EnsLib.HL7.Service.FileService" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true" Schedule="">
    <Setting Target="Host" Name="TargetConfigNames">HL7</Setting>
    <Setting Target="Host" Name="AddNackERR">1</Setting>
    <Setting Target="Host" Name="NackErrorCode">AllE</Setting>
    <Setting Target="Host" Name="SaveReplies">All</Setting>
  </Item>
  <Item Name="Patient Information from IHE PAM - MLLP" Category="" ClassName="EnsLib.HL7.Service.TCPService" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
    <Setting Target="Adapter" Name="JobPerConnection">1</Setting>
    <Setting Target="Host" Name="TargetConfigNames">HL7</Setting>
  </Item>
  <Item Name="Patient Information from IHE PAM - FILE" Category="" ClassName="EnsLib.HL7.Service.FileService" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
    <Setting Target="Host" Name="TargetConfigNames">HL7</Setting>
  </Item>
  <Item Name="forward to LAB RESULT from DGLAB - FILE" Category="" ClassName="EnsLib.HL7.Operation.FileOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true" Schedule="">
  </Item>
  <Item Name="LAB RESULT from DGLAB - HTTP" Category="" ClassName="EnsLib.HL7.Service.HTTPService" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true" Schedule="">
    <Setting Target="Host" Name="TargetConfigNames">HL7</Setting>
    <Setting Target="Host" Name="AddNackERR">1</Setting>
    <Setting Target="Host" Name="EnableStandardRequests">1</Setting>
  </Item>
  <Item Name="Patient Information from IHE PAM - HTTP" Category="" ClassName="EnsLib.HL7.Service.HTTPService" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true" Schedule="">
    <Setting Target="Host" Name="TargetConfigNames">HL7</Setting>
    <Setting Target="Host" Name="AddNackERR">1</Setting>
    <Setting Target="Host" Name="EnableStandardRequests">1</Setting>
    <Setting Target="Adapter" Name="JobPerConnection">1</Setting>
    <Setting Target="Adapter" Name="Port">9981</Setting>
  </Item>
  <Item Name="forward Patient Information to DGLAB - MLLP" Category="" ClassName="EnsLib.HL7.Operation.TCPOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="forward Patient Information to DGLAB - FILE" Category="" ClassName="EnsLib.HL7.Operation.FileOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="forward Patient Information to DGLAB - HTTP" Category="" ClassName="EnsLib.HL7.Operation.HTTPOperation" PoolSize="1" Enabled="false" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="Patient Information from IHE PAM" Category="" ClassName="EnsLib.HL7.Service.FileService" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
    <Setting Target="Host" Name="TargetConfigNames">HL7</Setting>
  </Item>
</Production>
}

}
