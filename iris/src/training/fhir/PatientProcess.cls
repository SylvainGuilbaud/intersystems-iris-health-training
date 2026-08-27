/// Business process: accepts a mapped data.patient or a supplied FHIR Patient
/// resource and pushes it to the local FHIR server (FHIRTRAINING) through the
/// standard HS.FHIRServer.Interop.Operation. Supports create, upsert, and delete.
Class training.fhir.PatientProcess Extends Ens.BusinessProcess [ ClassType = persistent ]
{

/// Config name of the FHIR interop operation to call.
Property FHIROperation As Ens.DataType.ConfigName [ InitialExpression = "HS.FHIRServer.Interop.Operation" ];

/// FHIR endpoint (app key) of the target FHIR server.
Property Endpoint As %String(MAXLEN = 256) [ InitialExpression = "/csp/healthshare/training/fhir/r4" ];

/// Optional verb override. Empty selects POST or PUT from target resource existence.
Property DefaultHTTPMethod As %String(VALUELIST = ",POST,PUT,DELETE");

Parameter SETTINGS = "FHIROperation:Basic:selector?context={Ens.ContextSearch/ProductionItems?targets=1&productionName=@productionId},Endpoint:Basic,DefaultHTTPMethod:Basic";

Method OnRequest(pRequest As training.fhir.msg.PatientRequest, Output pResponse As training.fhir.msg.PatientResponse) As %Status
{
    Set pResponse = ##class(training.fhir.msg.PatientResponse).%New()
    Set pResponse.PatientId = pRequest.PatientId

    Set method = $ZConvert($Select(pRequest.HTTPMethod '= "": pRequest.HTTPMethod, 1: ..DefaultHTTPMethod), "U")

    If pRequest.ResourceStreamId '= "" {
        Set sourceStream = ##class(HS.SDA3.QuickStream).%OpenId(pRequest.ResourceStreamId, , .sc)
        Quit:$$$ISERR(sc) sc
        If '$IsObject(sourceStream) Quit $$$ERROR($$$GeneralError, "FHIR Patient request stream is unavailable")
        Do sourceStream.Rewind()
        Set parseStatus = $$$OK
        Try {
            Set resource = {}.%FromJSON(sourceStream)
        } Catch exception {
            Set parseStatus = $$$ERROR($$$GeneralError, "Invalid FHIR JSON: "_exception.DisplayString())
        }
        Quit:$$$ISERR(parseStatus) parseStatus
        If resource.resourceType '= "Patient" Quit $$$ERROR($$$GeneralError, "resourceType must be Patient")
        If method = "" Set method = "POST"
    } Else {
        If pRequest.PatientId = "" Quit $$$ERROR($$$GeneralError, "PatientId or ResourceStreamId is required")
        Set resource = ##class(training.fhir.PatientMapper).ToResource(pRequest.PatientId, 1, .sc)
        Quit:$$$ISERR(sc) sc
    }

    If (pRequest.ResourceStreamId = "") && ((method = "") || (method = "DELETE")) {
        Set ipp = resource.identifier.%Get(0).value
        Set sc = ..FindResourceByIPP(ipp, .exists, .targetResourceId)
        Quit:$$$ISERR(sc) sc
        If method = "DELETE", 'exists {
            Set pResponse.HTTPMethod = method
            Set pResponse.HTTPStatus = 404
            Quit $$$OK
        }
        If method = "" Set method = $Select(exists: "PUT", 1: "POST")
        If exists Set resource.id = targetResourceId
        If method = "DELETE" Set pResponse.ResourceId = targetResourceId
    }
    If (method '= "POST") && (method '= "PUT") && (method '= "DELETE") {
        Quit $$$ERROR($$$GeneralError, "Unsupported FHIR method '"_method_"'; expected POST, PUT, or DELETE")
    }
    Set pResponse.HTTPMethod = method
    If method = "POST" Do resource.%Remove("id")

    If method '= "DELETE" {
        // Carry the JSON body in a QuickStream (as the FHIR interop operation expects)
        Set quickStream = ##class(HS.SDA3.QuickStream).%New()
        Do quickStream.Write(resource.%ToJSON())
        Do quickStream.Flush()
        $$$ThrowOnError(quickStream.%Save())
    }

    // Build the FHIR request
    Set fhirRequest = ##class(HS.FHIRServer.API.Data.Request).%New()
    Set fhirRequest.RequestMethod = method
    Set fhirRequest.SessionApplication = ..Endpoint
    Set fhirRequest.RequestFormatCode = "JSON"
    Set fhirRequest.RequestPath = $Select((method = "PUT") || (method = "DELETE"): "/Patient/" _ resource.id, 1: "/Patient")

    Set interopRequest = ##class(HS.FHIRServer.Interop.Request).%New()
    Set interopRequest.Request = fhirRequest
    If method '= "DELETE" Set interopRequest.QuickStreamId = quickStream.%Id()

    // Call the FHIR server through the standard interop operation
    Set sc = ..SendRequestSync(..FHIROperation, interopRequest, .interopResponse)
    Quit:$$$ISERR(sc) sc

    If $IsObject($Get(interopResponse)) && $IsObject(interopResponse.Response) {
        Set pResponse.HTTPStatus = interopResponse.Response.Status
        If interopResponse.Response.Id '= "" Set pResponse.ResourceId = interopResponse.Response.Id
    }

    // Flag an application-level failure (4xx/5xx) as an error status
    If (+pResponse.HTTPStatus >= 400) {
        Quit $$$ERROR($$$GeneralError, "FHIR server returned HTTP " _ pResponse.HTTPStatus _ " for patient " _ pRequest.PatientId)
    }

    Quit $$$OK
}

/// Find a target Patient by its IPP and return its server-assigned logical id.
Method FindResourceByIPP(pIPP As %String, Output pExists As %Boolean, Output pResourceId As %String) As %Status
{
    Set pExists = 0
    Set pResourceId = ""
    Set identifier = ##class(%CSP.Page).EscapeURL($Parameter("training.fhir.PatientMapper", "IPPSYSTEM")_"|"_pIPP)
    Set fhirRequest = ##class(HS.FHIRServer.API.Data.Request).%New()
    Set fhirRequest.RequestMethod = "GET"
    Set fhirRequest.SessionApplication = ..Endpoint
    Set fhirRequest.RequestFormatCode = "JSON"
    Set fhirRequest.RequestPath = "/Patient?identifier=" _ identifier _ "&_count=1"

    Set interopRequest = ##class(HS.FHIRServer.Interop.Request).%New()
    Set interopRequest.Request = fhirRequest
    Set sc = ..SendRequestSync(..FHIROperation, interopRequest, .interopResponse)
    Quit:$$$ISERR(sc) sc
    If '$IsObject($Get(interopResponse)) || '$IsObject(interopResponse.Response) {
        Quit $$$ERROR($$$GeneralError, "FHIR search returned no response for IPP '"_pIPP_"'")
    }

    Set httpStatus = +interopResponse.Response.Status
    If (httpStatus < 200) || (httpStatus >= 300) {
        Quit $$$ERROR($$$GeneralError, "FHIR search returned HTTP "_httpStatus_" for IPP '"_pIPP_"'")
    }
    If interopResponse.QuickStreamId = "" Quit $$$OK

    Set stream = ##class(HS.SDA3.QuickStream).%OpenId(interopResponse.QuickStreamId, , .sc)
    Quit:$$$ISERR(sc) sc
    If '$IsObject(stream) Quit $$$ERROR($$$GeneralError, "FHIR search response stream is unavailable")
    Do stream.Rewind()
    Set bundle = {}.%FromJSON(stream)
    If bundle.entry.%Size() = 0 Quit $$$OK

    Set pResourceId = bundle.entry.%Get(0).resource.id
    If pResourceId = "" Quit $$$ERROR($$$GeneralError, "FHIR search result has no Patient id")
    Set pExists = 1
    Quit $$$OK
}

Storage Default
{
<Data name="PatientProcessDefaultData">
<Subscript>"PatientProcess"</Subscript>
<Value name="1">
<Value>FHIROperation</Value>
</Value>
<Value name="2">
<Value>Endpoint</Value>
</Value>
<Value name="3">
<Value>DefaultHTTPMethod</Value>
</Value>
</Data>
<DefaultData>PatientProcessDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
