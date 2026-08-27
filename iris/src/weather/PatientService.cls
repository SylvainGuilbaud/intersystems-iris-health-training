Include %occStatus

Class weather.PatientService Extends Ens.BusinessService
{

Parameter ADAPTER;

Property TargetConfigName As Ens.DataType.ConfigName [ InitialExpression = "weather.PatientProcess" ];

Parameter SETTINGS = "TargetConfigName:Basic:selector?context={Ens.ContextSearch/ProductionItems?targets=1&productionName=@productionId}";

Method OnProcessInput(pInput As %RegisteredObject, Output pOutput As %RegisteredObject) As %Status
{
    Set pOutput = ""
    Quit $$$OK
}

ClassMethod EnrichPatient(pPatientId As %String, Output pResource As %DynamicObject, pConfigName As %String = "weather.PatientService") As %Status
{
    Set pResource = ""
    Set sc = ##class(Ens.Director).CreateBusinessService(pConfigName, .service)
    Quit:$$$ISERR(sc) sc

    Set request = ##class(weather.msg.PatientEnrichmentRequest).%New()
    Set request.PatientId = pPatientId
    Set sc = service.SendRequestSync(service.TargetConfigName, request, .response)
    Quit:$$$ISERR(sc) sc
    If '$IsObject(response) || (response.ResourceStreamId = "") {
        Quit $$$ERROR($$$GeneralError, "Patient enrichment returned no FHIR resource")
    }

    Set stream = ##class(HS.SDA3.QuickStream).%OpenId(response.ResourceStreamId, , .sc)
    Quit:$$$ISERR(sc) sc
    If '$IsObject(stream) Quit $$$ERROR($$$GeneralError, "Enriched Patient stream is unavailable")
    Do stream.Rewind()
    Set parseStatus = $$$OK
    Try {
        Set pResource = {}.%FromJSON(stream)
    } Catch exception {
        Set parseStatus = $$$ERROR($$$GeneralError, "Invalid enriched Patient JSON: "_exception.DisplayString())
    }
    Quit:$$$ISERR(parseStatus) parseStatus
    Quit $$$OK
}

}