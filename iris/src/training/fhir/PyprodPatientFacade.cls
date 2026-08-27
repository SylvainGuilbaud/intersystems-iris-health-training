Include %occStatus

Class training.fhir.PyprodPatientFacade
{

ClassMethod EnrichPatient(pPatientId As %String, Output pResource As %DynamicObject, pConfigName As %String = "pyprod.PatientService") As %Status
{
    Set pResource = ""
    Set request = ##class(pyprod.PatientEnrichmentRequest).%New()
    Set request.SerializedStream = ##class(%Stream.GlobalCharacter).%New()
    Set payload = {"patient_id": (pPatientId)}
    Do request.SerializedStream.Write(payload.%ToJSON())

    Set sc = ##class(Ens.Director).CreateBusinessService(pConfigName, .service)
    Quit:$$$ISERR(sc) sc
    Set sc = service.OnProcessInput(request, .response)
    Quit:$$$ISERR(sc) sc
    If '$IsObject(response) || '$IsObject(response.SerializedStream) {
        Quit $$$ERROR($$$GeneralError, "Python Patient enrichment returned no FHIR resource")
    }

    Do response.SerializedStream.Rewind()
    Set envelope = {}.%FromJSON(response.SerializedStream)
    If '$IsObject(envelope.resource) {
        Quit $$$ERROR($$$GeneralError, "Python Patient enrichment returned an invalid FHIR resource")
    }
    Set pResource = envelope.resource
    Quit $$$OK
}

}