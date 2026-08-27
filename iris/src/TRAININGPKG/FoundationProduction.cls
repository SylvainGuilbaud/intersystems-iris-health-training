/// Production definition for the Foundation Production, which is used to run the FHIR training project.
Class TRAININGPKG.FoundationProduction Extends Ens.Production [ Not ProcedureBlock ]
{

XData ProductionDefinition
{
<Production Name="TRAININGPKG.FoundationProduction" LogGeneralTraceEvents="false">
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
  <Item Name="training.fhir.PatientService" Category="FHIR" ClassName="training.fhir.PatientService" PoolSize="1" Enabled="true" Foreground="false" Comment="Reads data.patient and feeds patients to the FHIR flow">
    <Setting Target="Host" Name="TargetConfigName">training.fhir.PatientProcess</Setting>
  </Item>
  <Item Name="training.fhir.PatientProcess" Category="FHIR" ClassName="training.fhir.PatientProcess" PoolSize="1" Enabled="true" Foreground="false" Comment="Maps data.patient to FHIR Patient and sends POST/PUT">
    <Setting Target="Host" Name="FHIROperation">HS.FHIRServer.Interop.Operation</Setting>
    <Setting Target="Host" Name="Endpoint">/csp/healthshare/training/fhir/r4</Setting>
  </Item>
  <Item Name="HS.FHIRServer.Interop.Operation" Category="FHIR" ClassName="HS.FHIRServer.Interop.Operation" PoolSize="1" Enabled="true" Foreground="false" Comment="Standard FHIR server interop operation (target: FHIRTRAINING)">
  </Item>
  <Item Name="weather.PatientService" Category="FHIR Enrichment" ClassName="weather.PatientService" PoolSize="1" Enabled="true" Foreground="false" Comment="Receives synchronous Patient enrichment requests">
    <Setting Target="Host" Name="TargetConfigName">weather.PatientProcess</Setting>
  </Item>
  <Item Name="weather.PatientProcess" Category="FHIR Enrichment" ClassName="weather.PatientProcess" PoolSize="1" Enabled="true" Foreground="false" Comment="Adds geocoding and current weather to FHIR Patient resources">
    <Setting Target="Host" Name="GeocodingOperation">weather.GeocodingOperation</Setting>
    <Setting Target="Host" Name="WeatherOperation">weather.WeatherOperation</Setting>
  </Item>
  <Item Name="weather.GeocodingOperation" Category="FHIR Enrichment" ClassName="weather.GeocodingOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="Resolves patient cities with Open-Meteo geocoding">
    <Setting Target="Host" Name="Server">geocoding-api.open-meteo.com</Setting>
    <Setting Target="Host" Name="SSLConfiguration">BFC_SSL</Setting>
  </Item>
  <Item Name="weather.WeatherOperation" Category="FHIR Enrichment" ClassName="weather.WeatherOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="Retrieves current temperatures from Open-Meteo">
    <Setting Target="Host" Name="Server">api.open-meteo.com</Setting>
    <Setting Target="Host" Name="SSLConfiguration">BFC_SSL</Setting>
  </Item>
  <Item Name="pyprod.PatientService" Category="FHIR Enrichment Python" ClassName="pyprod.PatientService" PoolSize="0" Enabled="true" Foreground="false" Comment="Receives Python Patient enrichment requests">
    <Setting Target="Host" Name="TargetConfigName">pyprod.PatientProcess</Setting>
  </Item>
  <Item Name="pyprod.PatientProcess" Category="FHIR Enrichment Python" ClassName="pyprod.PatientProcess" PoolSize="0" Enabled="true" Foreground="false" Comment="Adds geocoding and weather using intersystems-pyprod">
    <Setting Target="Host" Name="GeocodingOperation">pyprod.GeocodingOperation</Setting>
    <Setting Target="Host" Name="WeatherOperation">pyprod.WeatherOperation</Setting>
  </Item>
  <Item Name="pyprod.GeocodingOperation" Category="FHIR Enrichment Python" ClassName="pyprod.GeocodingOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="Resolves cities with Open-Meteo from Python">
    <Setting Target="Host" Name="Server">geocoding-api.open-meteo.com</Setting>
    <Setting Target="Host" Name="Timeout">10</Setting>
  </Item>
  <Item Name="pyprod.WeatherOperation" Category="FHIR Enrichment Python" ClassName="pyprod.WeatherOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="Retrieves current temperatures from Python">
    <Setting Target="Host" Name="Server">api.open-meteo.com</Setting>
    <Setting Target="Host" Name="Timeout">10</Setting>
  </Item>
</Production>
}

}
