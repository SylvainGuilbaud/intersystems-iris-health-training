Include %occStatus

/// REST facade over data.patient using the IRIS R4 FHIR object model mapping.
Class training.fhir.PatientREST Extends %CSP.REST 
{

Parameter UseSession = 0;

Parameter HandleCorsRequest = 1;

/// OpenAPI contract associated with this dispatch class.
Parameter SpecificationClass = "training.fhir.PatientRESTSpec";

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
  <Route Url="/version" Method="GET" Call="GetVersion" />
  <Route Url="/versionpy" Method="GET" Call="GetVersionPyResponse" />
  <Route Url="/Patient/:id" Method="GET" Call="GetPatient" />
  <Route Url="/Patient/:id" Method="POST" Call="SyncPatient" />
  <Route Url="/Patient/:id" Method="PUT" Call="PutPatient" />
    <Route Url="/Patient/:id" Method="DELETE" Call="DeletePatient" />
</Routes>
}

/// Return non-sensitive details about the current IRIS instance.
ClassMethod GetVersion() As %Status
{
        Set details = {}
        Set details.system = $System
        Set details.instance = $System.Util.GetEnviron("ISC_PACKAGE_INSTANCENAME")
        Set details.hostname = $System.Util.GetEnviron("HOSTNAME")
        Set details.namespace = $Namespace
        Set details.version = $ZVersion
        Set details.timestamp = $ZDateTime($Horolog, 3, 1, 3)
        //set details.uptime = $ZDateTime($System.Process.GetUptime(), 3, 1, 3)
        set details.username = $USERNAME

        Set %response.Status = 200
        Set %response.ContentType = "application/json"
        Write details.%ToJSON()
        Quit $$$OK
}

/// Write the Embedded Python version response to the current HTTP device.
ClassMethod GetVersionPyResponse() As %Status
{
    Set %response.Status = 200
    Set %response.ContentType = "application/json"
    Write ..GetVersionPy($Username)
    Quit $$$OK
}

/// Return non-sensitive IRIS instance details as JSON using Embedded Python.
ClassMethod GetVersionPy(username As %String) As %String [ Language = python ]
{
import datetime
import json
import os
import socket
import time

import iris

instance = os.getenv("ISC_PACKAGE_INSTANCENAME", "")
hostname = os.getenv("HOSTNAME") or socket.gethostname()
uptime_seconds = int(time.monotonic())
details = {
    "system": f"{hostname}:{instance}",
    "instance": instance,
    "hostname": hostname,
    "namespace": iris.cls("%SYSTEM.SYS").NameSpace(),
    "version": iris.cls("%SYSTEM.Version").GetVersion(),
    "timestamp": datetime.datetime.now().isoformat(sep=" ", timespec="milliseconds"),
    "uptime": str(datetime.timedelta(seconds=uptime_seconds)),
    "username": username,
}
return json.dumps(details)
}

/// Project a data.patient record as an R4 FHIR Patient without persisting it.
ClassMethod GetPatient(id As %String) As %Status
{
    If '##class(data.patient).%ExistsId(id) {
        Do ..WriteError(404, "not-found", "data.patient '"_id_"' not found")
        Quit $$$OK
    }

    Set resource = ##class(training.fhir.PatientMapper).ToResource(id, 1, .sc)
    If $$$ISERR(sc) {
        Do ..WriteError(500, "exception", $System.Status.GetErrorText(sc))
        Quit $$$OK
    }

    Set %response.Status = 200
    Set %response.ContentType = "application/fhir+json"
    Write resource.%ToJSON()
    Quit $$$OK
}

/// Synchronize a source patient, selecting POST or PUT from FHIR target existence.
ClassMethod SyncPatient(id As %String) As %Status
{
    Quit ..SendPatient(id, "")
}

/// Force an idempotent PUT of a source patient to the FHIR target.
ClassMethod PutPatient(id As %String) As %Status
{
    If '##class(data.patient).%ExistsId(id) {
        Do ..WriteError(404, "not-found", "data.patient '"_id_"' not found")
        Quit $$$OK
    }

    Set sc = ..UpdateAddressFromPayload(id, .httpStatus)
    If $$$ISERR(sc) {
        Do ..WriteError(httpStatus, "invalid", $System.Status.GetErrorText(sc))
        Quit $$$OK
    }
    Quit ..SendPatient(id, "PUT")
}

/// Delete the Patient mapped from the source patient in the FHIR target.
ClassMethod DeletePatient(id As %String) As %Status
{
    If '##class(data.patient).%ExistsId(id) {
        Do ..WriteError(404, "not-found", "data.patient '"_id_"' not found")
        Quit $$$OK
    }

    Set sc = ##class(training.fhir.PatientService).SendPatientDetails(id, "DELETE", .details)
    If $$$ISERR(sc) {
        Do ..WriteError(502, "exception", $System.Status.GetErrorText(sc))
        Quit $$$OK
    }
    If +details.HTTPStatus = 404 {
        Do ..WriteError(404, "not-found", "FHIR Patient for data.patient '"_id_"' not found")
        Quit $$$OK
    }

    Set %response.Status = 204
    Do %response.SetHeader("X-FHIR-HTTP-Method", "DELETE")
    If details.ResourceId '= "" Do %response.SetHeader("Content-Location", "Patient/"_details.ResourceId)
    Quit $$$OK
}

/// Import the editable home address while keeping the source id and IPP immutable.
ClassMethod UpdateAddressFromPayload(id As %String, Output httpStatus As %Integer) As %Status
{
    Set httpStatus = 400
    Set parseStatus = $$$OK
    Try {
        Set payload = {}.%FromJSON(%request.Content)
    } Catch exception {
        Set parseStatus = $$$ERROR($$$GeneralError, "Invalid FHIR JSON: "_exception.DisplayString())
    }
    Quit:$$$ISERR(parseStatus) parseStatus

    If payload.resourceType '= "Patient" {
        Quit $$$ERROR($$$GeneralError, "resourceType must be Patient")
    }

    Set patient = ##class(data.patient).%OpenId(id, , .sc)
    Quit:$$$ISERR(sc) sc
    Set expectedId = ##class(training.fhir.PatientMapper).LogicalId(patient.IPP)
    If (payload.id '= "") && (payload.id '= expectedId) {
        Set httpStatus = 409
        Quit $$$ERROR($$$GeneralError, "Patient id is immutable; expected '"_expectedId_"'")
    }

    If $IsObject(payload.identifier) {
        Set ippChanged = 0
        Set iterator = payload.identifier.%GetIterator()
        While iterator.%GetNext(.key, .identifier) {
            If identifier.system = $Parameter("training.fhir.PatientMapper", "IPPSYSTEM") {
                If identifier.value '= patient.IPP {
                    Set ippChanged = 1
                    Quit
                }
            }
        }
        If ippChanged {
            Set httpStatus = 409
            Quit $$$ERROR($$$GeneralError, "Patient IPP is immutable; expected '"_patient.IPP_"'")
        }
    }

    If '$IsObject(payload.address) || (payload.address.%Size() = 0) {
        Quit $$$ERROR($$$GeneralError, "A Patient address is required")
    }
    Set address = payload.address.%Get(0)
    Set iterator = payload.address.%GetIterator()
    While iterator.%GetNext(.key, .candidate) {
        If candidate.use = "home" Set address = candidate Quit
    }

    If '$IsObject(patient.homeAddress) Set patient.homeAddress = ##class(data.address).%New()
    If address.%IsDefined("line") {
        Set patient.homeAddress.Street = address.line.%Get(0)
        Set patient.homeAddress.RecipientComplement = address.line.%Get(1)
        Set patient.homeAddress.GeographicComplement = address.line.%Get(2)
        Set patient.homeAddress.LocalityPOBox = address.line.%Get(3)
    }
    If address.%IsDefined("city") Set patient.homeAddress.City = address.city
    If address.%IsDefined("postalCode") Set patient.homeAddress.PostalCode = address.postalCode
    If address.%IsDefined("country") Set patient.homeAddress.Country = address.country
    Set patient.updatedAt = $ZDateTime($Horolog, 3)

    TSTART
    Set sc = patient.%Save()
    If $$$ISERR(sc) {
        TROLLBACK
        Quit sc
    }
    TCOMMIT
    Quit $$$OK
}

ClassMethod SendPatient(id As %String, method As %String) As %Status
{
    If '##class(data.patient).%ExistsId(id) {
        Do ..WriteError(404, "not-found", "data.patient '"_id_"' not found")
        Quit $$$OK
    }

    Set sc = ##class(training.fhir.PatientService).SendPatientDetails(id, method, .details)
    If $$$ISERR(sc) {
        Do ..WriteError(502, "exception", $System.Status.GetErrorText(sc))
        Quit $$$OK
    }

    Set resource = ##class(training.fhir.PatientMapper).ToResource(id, 1, .mapSC)
    If $$$ISERR(mapSC) {
        Do ..WriteError(500, "exception", $System.Status.GetErrorText(mapSC))
        Quit $$$OK
    }
    If details.ResourceId '= "" Set resource.id = details.ResourceId

    Set %response.Status = $Select(+details.HTTPStatus > 0: +details.HTTPStatus, 1: 200)
    Set %response.ContentType = "application/fhir+json"
    Do %response.SetHeader("X-FHIR-HTTP-Method", details.HTTPMethod)
    If details.ResourceId '= "" Do %response.SetHeader("Content-Location", "Patient/"_details.ResourceId)
    Write resource.%ToJSON()
    Quit $$$OK
}

ClassMethod WriteError(httpStatus As %Integer, code As %String, diagnostics As %String)
{
    Set outcome = {"resourceType":"OperationOutcome","issue":[]}
    Do outcome.issue.%Push({"severity":"error","code":(code),"diagnostics":(diagnostics)})
    Set %response.Status = httpStatus
    Set %response.ContentType = "application/fhir+json"
    Write outcome.%ToJSON()
}

/// Idempotently install the CSP application that exposes this dispatch class.
ClassMethod Install(pWebApp As %String = "/fhir", pNamespace As %String = {$Namespace}) As %Status
{
    Set currentNamespace = $Namespace
    ZN "%SYS"
    Set properties("NameSpace") = pNamespace
    Set properties("DispatchClass") = "training.fhir.PatientREST"
    Set properties("Enabled") = 1
    Set properties("AutheEnabled") = 32
    Set properties("UseSessionCookie") = 0
    Set properties("Recurse") = 1
    If ##class(Security.Applications).Exists(pWebApp) {
        Set sc = ##class(Security.Applications).Modify(pWebApp, .properties)
    } Else {
        Set sc = ##class(Security.Applications).Create(pWebApp, .properties)
    }
    Set versionApp = pWebApp _ "/version"
    If $$$ISOK(sc) && ##class(Security.Applications).Exists(versionApp) {
        Set sc = ##class(Security.Applications).Delete(versionApp)
    }
    ZN currentNamespace
    Quit sc
}

}