Include %occStatus

/// REST facade over data.patient with R4 FHIR Patient representations.<br/>
/// Business logic class defined by OpenAPI in fhirfoch.spec<br/>
/// Updated Aug 26, 2026 16:24:36
Class fhirfoch.impl Extends %REST.Impl [ ProcedureBlock ]
{

/// If ExposeServerExceptions is true, then details of internal errors will be exposed.
Parameter ExposeServerExceptions = 0;

/// Get IRIS instance details
ClassMethod GetVersion() As %DynamicObject
{
    Set details = {}
    Set details.system = $System
    Set details.instance = $System.Util.GetEnviron("ISC_PACKAGE_INSTANCENAME")
    Set details.hostname = $System.Util.GetEnviron("HOSTNAME")
    Set details.namespace = $Namespace
    Set details.version = $ZVersion
    Set details.timestamp = $ZDateTime($Horolog, 3, 1, 3)
    Set details.username = $Username

    Set namespaces = []
    Do namespaces.%Push("toto")
    Do namespaces.%Push("tata")
    Do namespaces.%Push("titi")
    Set details.namespaces = namespaces

    Do ..%SetStatusCode(200)
    Quit details
}

/// Get IRIS instance details from Embedded Python
ClassMethod GetVersionPyResponse() As %DynamicObject
{
    Set details = {}.%FromJSON(##class(training.fhir.PatientREST).GetVersionPy($Username))
    Do ..%SetStatusCode(200)
    Quit details
}

/// Returns the mapped Patient without persisting it to the FHIR repository.<br/>
/// The method arguments hold values for:<br/>
///     ipp, Patient IPP<br/>
ClassMethod GetPatient(ipp As %String) As %Stream.Object
{
    Set patientId = ##class(training.fhir.PatientMapper).FindPatientIdByIPP(ipp, .findStatus)
    If $$$ISERR(findStatus) Quit ..ErrorResponse(500, "exception", $System.Status.GetErrorText(findStatus))
    If patientId = "" Quit ..ErrorResponse(404, "not-found", "Patient with IPP '"_ipp_"' not found")

    Set sc = ##class(weather.PatientService).EnrichPatient(patientId, .resource)
    If $$$ISERR(sc) {
        Quit ..ErrorResponse(502, "exception", $System.Status.GetErrorText(sc))
    }

    Do ..%SetStatusCode(200)
    Quit resource.%ToJSON()
}

/// Creates or updates the target Patient from the supplied FHIR resource.<br/>
/// The method arguments hold values for:<br/>
///     body, FHIR Patient to synchronize.<br/>
///     target, Persistence target: fhir (default) or data.<br/>
ClassMethod SyncPatient(body As %Stream.Object, target As %String = "fhir") As %Stream.Object
{
    Set resource = ..ParsePatient(body, .parseStatus)
    If $$$ISERR(parseStatus) Quit ..ErrorResponse(400, "invalid", $System.Status.GetErrorText(parseStatus))

    Set target = $ZConvert(target, "L")
    If target = "" Set target = "fhir"
    If (target '= "fhir") && (target '= "data") Quit ..ErrorResponse(400, "invalid", "target must be 'fhir' or 'data'")

    If target = "data" {
        Set sc = ##class(training.fhir.PatientMapper).SaveToData(resource, "", .patientId)
        If $$$ISERR(sc) Quit ..ErrorResponse(400, "invalid", $System.Status.GetErrorText(sc))
        Set response = ##class(training.fhir.PatientMapper).ToResource(patientId, 1, .mapStatus)
        If $$$ISERR(mapStatus) Quit ..ErrorResponse(500, "exception", $System.Status.GetErrorText(mapStatus))
        Do ..%SetStatusCode(201)
        Do ..%SetHeader("Content-Location", "Patient/"_patientId)
        Quit response.%ToJSON()
    }

    Quit ..SendFHIRResource(resource, "POST")
}

/// Updates the FHIR resource or data.patient according to target.<br/>
/// The method arguments hold values for:<br/>
///     ipp, Patient IPP<br/>
///     body, FHIR Patient to update.<br/>
///     target, Persistence target: fhir (default) or data.<br/>
ClassMethod PutPatient(ipp As %String, body As %Stream.Object, target As %String = "fhir") As %Stream.Object
{
    Set resource = ..ParsePatient(body, .parseStatus)
    If $$$ISERR(parseStatus) Quit ..ErrorResponse(400, "invalid", $System.Status.GetErrorText(parseStatus))

    Set target = $ZConvert(target, "L")
    If target = "" Set target = "fhir"
    If (target '= "fhir") && (target '= "data") Quit ..ErrorResponse(400, "invalid", "target must be 'fhir' or 'data'")

    If target = "data" {
        Set patientId = ##class(training.fhir.PatientMapper).FindPatientIdByIPP(ipp, .findStatus)
        If $$$ISERR(findStatus) Quit ..ErrorResponse(500, "exception", $System.Status.GetErrorText(findStatus))
        If patientId = "" Quit ..ErrorResponse(404, "not-found", "Patient with IPP '"_ipp_"' not found")
        Set sc = ##class(training.fhir.PatientMapper).SaveToData(resource, patientId, .patientId)
        If $$$ISERR(sc) Quit ..ErrorResponse(400, "invalid", $System.Status.GetErrorText(sc))
        Set response = ##class(training.fhir.PatientMapper).ToResource(patientId, 1, .mapStatus)
        If $$$ISERR(mapStatus) Quit ..ErrorResponse(500, "exception", $System.Status.GetErrorText(mapStatus))
        Do ..%SetStatusCode(200)
        Do ..%SetHeader("Content-Location", "Patient/"_ipp)
        Quit response.%ToJSON()
    }

    Set resourceIPP = ##class(training.fhir.PatientMapper).IdentifierValue(resource, $Parameter("training.fhir.PatientMapper", "IPPSYSTEM"))
    If resourceIPP = "" Quit ..ErrorResponse(400, "invalid", "The Patient IPP identifier is required")
    If resourceIPP '= ipp Quit ..ErrorResponse(409, "invalid", "Patient IPP must match the path IPP '"_ipp_"'")
    Set logicalId = ##class(training.fhir.PatientMapper).LogicalId(ipp)
    If (resource.id '= "") && (resource.id '= logicalId) Quit ..ErrorResponse(409, "invalid", "Patient id must match the logical id '"_logicalId_"'")
    Set resource.id = logicalId
    Quit ..SendFHIRResource(resource, "PUT")
}

/// Finds the target Patient by the source patient's IPP and deletes it. The data.patient source record is preserved.<br/>
/// The method arguments hold values for:<br/>
///     ipp, Patient IPP<br/>
ClassMethod DeletePatient(ipp As %String) As %Stream.Object
{
    Set patientId = ##class(training.fhir.PatientMapper).FindPatientIdByIPP(ipp, .findStatus)
    If $$$ISERR(findStatus) Quit ..ErrorResponse(500, "exception", $System.Status.GetErrorText(findStatus))
    If patientId = "" Quit ..ErrorResponse(404, "not-found", "Patient with IPP '"_ipp_"' not found")

    Set sc = ##class(training.fhir.PatientService).SendPatientDetails(patientId, "DELETE", .details)
    If $$$ISERR(sc) {
        Quit ..ErrorResponse(502, "exception", $System.Status.GetErrorText(sc))
    }
    If +details.HTTPStatus = 404 {
        Quit ..ErrorResponse(404, "not-found", "FHIR Patient with IPP '"_ipp_"' not found")
    }

    Do ..%SetStatusCode(204)
    Do ..%SetHeader("X-FHIR-HTTP-Method", "DELETE")
    If details.ResourceId '= "" Do ..%SetHeader("Content-Location", "Patient/"_details.ResourceId)
    Quit ""
}

/// Synchronize one source patient and return its mapped FHIR representation.
ClassMethod SendPatient(id As %String, method As %String) As %Stream.Object
{
    If '##class(data.patient).%ExistsId(id) {
        Quit ..ErrorResponse(404, "not-found", "data.patient '"_id_"' not found")
    }

    Set sc = ##class(training.fhir.PatientService).SendPatientDetails(id, method, .details)
    If $$$ISERR(sc) {
        Quit ..ErrorResponse(502, "exception", $System.Status.GetErrorText(sc))
    }

    Set resource = ##class(training.fhir.PatientMapper).ToResource(id, 1, .mapSC)
    If $$$ISERR(mapSC) {
        Quit ..ErrorResponse(500, "exception", $System.Status.GetErrorText(mapSC))
    }
    If details.ResourceId '= "" Set resource.id = details.ResourceId

    Do ..%SetStatusCode($Select(+details.HTTPStatus > 0: +details.HTTPStatus, 1: 200))
    Do ..%SetHeader("X-FHIR-HTTP-Method", details.HTTPMethod)
    If details.ResourceId '= "" Do ..%SetHeader("Content-Location", "Patient/"_details.ResourceId)
    Quit resource.%ToJSON()
}

/// Send a supplied Patient resource directly to the FHIR repository.
ClassMethod SendFHIRResource(resource As %DynamicObject, method As %String) As %Stream.Object
{
    Set sc = ##class(training.fhir.PatientService).SendFHIRPatientDetails(resource, .details, method)
    If $$$ISERR(sc) Quit ..ErrorResponse(502, "exception", $System.Status.GetErrorText(sc))

    If details.ResourceId '= "" Set resource.id = details.ResourceId
    Do ..%SetStatusCode($Select(+details.HTTPStatus > 0: +details.HTTPStatus, method = "POST": 201, 1: 200))
    Do ..%SetHeader("X-FHIR-HTTP-Method", details.HTTPMethod)
    If details.ResourceId '= "" Do ..%SetHeader("Content-Location", "Patient/"_details.ResourceId)
    Quit resource.%ToJSON()
}

/// Parse and validate a FHIR Patient request body.
ClassMethod ParsePatient(body As %Stream.Object, Output status As %Status) As %DynamicObject
{
    Set status = $$$OK
    Try {
        Set resource = {}.%FromJSON(body)
    } Catch exception {
        Set status = $$$ERROR($$$GeneralError, "Invalid FHIR JSON: "_exception.DisplayString())
        Quit
    }
    If resource.resourceType '= "Patient" Set status = $$$ERROR($$$GeneralError, "resourceType must be Patient")
    Quit resource
}

/// Build a FHIR OperationOutcome and apply its HTTP status.
ClassMethod ErrorResponse(httpStatus As %Integer, code As %String, diagnostics As %String) As %Stream.Object
{
    Set outcome = {"resourceType":"OperationOutcome","issue":[]}
    Do outcome.issue.%Push({"severity":"error","code":(code),"diagnostics":(diagnostics)})
    Do ..%SetStatusCode(httpStatus)
    Quit outcome.%ToJSON()
}

}
