Class TRAININGPKG.FoundationProduction Extends Ens.Production [ Not ProcedureBlock ]
{

XData ProductionDefinition
{
<Production Name="TRAININGPKG.FoundationProduction" LogGeneralTraceEvents="false">
  <Item Name="training.fhir.PatientService" Category="FHIR" ClassName="training.fhir.PatientService" PoolSize="1" Enabled="true" Foreground="false" Comment="Reads data.patient and feeds patients to the FHIR flow">
    <Setting Target="Host" Name="TargetConfigName">training.fhir.PatientProcess</Setting>
  </Item>
  <Item Name="training.fhir.PatientProcess" Category="FHIR" ClassName="training.fhir.PatientProcess" PoolSize="1" Enabled="true" Foreground="false" Comment="Maps data.patient to FHIR Patient and sends POST/PUT">
    <Setting Target="Host" Name="FHIROperation">HS.FHIRServer.Interop.Operation</Setting>
    <Setting Target="Host" Name="Endpoint">/csp/healthshare/training/fhir/r4</Setting>
  </Item>
  <Item Name="HS.FHIRServer.Interop.Operation" Category="FHIR" ClassName="HS.FHIRServer.Interop.Operation" PoolSize="1" Enabled="true" Foreground="false" Comment="Standard FHIR server interop operation (target: FHIRTRAINING)">
  </Item>
</Production>
}

}
