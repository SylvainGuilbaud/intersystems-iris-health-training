/// API minimale avec deux endpoints: /sql/{id} retourne les données SQL brutes, /fhir/{id} retourne un Patient FHIR.<br/>
/// Business logic class defined by OpenAPI in sqltofhir.spec<br/>
/// Updated Mar 3, 2026 17:53:57
Class sqltofhir.impl Extends %REST.Impl [ ProcedureBlock ]
{

/// If ExposeServerExceptions is true, then details of internal errors will be exposed.
Parameter ExposeServerExceptions = 0;

/// Récupérer les données patient au format SQL (JSON brut)<br/>
/// The method arguments hold values for:<br/>
///     id, Identifiant du patient côté SQL<br/>
ClassMethod getSqlPatientById(id As %String) As %DynamicObject
{
    set json = {}
    set json.id = id
    set tSC=##class(Ens.Director).CreateBusinessService("REST.service",.tService)
    set request = ##class(msg.request.patient).%New()
    set request.id = id
    set request.format = "sql"
    set sc=tService.ProcessInput(request,.response)
        
    if $ISOBJECT(response) {
            do response.%JSONExportToString(.bundleJSON)
            set json = {}.%FromJSON(bundleJSON)
    } else {
        set json.status = "Patient introuvable"
    }
    
    return json.%ToJSON()
}

/// Récupérer le patient au format FHIR (Patient)<br/>
/// The method arguments hold values for:<br/>
///     id, Identifiant du patient (mappé depuis l'ID SQL)<br/>
ClassMethod getFhirPatientById(id As %String) As %Stream.Object
{
    set json = {}
    set tSC=##class(Ens.Director).CreateBusinessService("REST.service",.tService)
    set request = ##class(msg.request.patient).%New()
    set request.id = id
    set request.format = "fhir"
    set sc=tService.ProcessInput(request,.response)
        
    if $ISOBJECT(response) {
        set json = {}.%FromJSON(response.json)
    } else {
        set json.status = "Patient introuvable"
    }
    
    return json.%ToJSON()
}

}
