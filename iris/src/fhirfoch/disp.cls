/// REST facade over data.patient with R4 FHIR Patient representations.
/// Dispatch class defined by RESTSpec in fhirfoch.spec
Class fhirfoch.disp Extends %CSP.REST [ GeneratedBy = fhirfoch.spec.cls, ProcedureBlock ]
{

/// The class containing the RESTSpec which generated this class
Parameter SpecificationClass = "fhirfoch.spec";

/// Ignore any writes done directly by the REST method.
Parameter IgnoreWrites = 1;

/// By default convert the input stream to Unicode
Parameter CONVERTINPUTSTREAM = 1;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
  <!-- Get IRIS instance details -->
  <Route Url="/version" Method="get" Call="GetVersion" />
  <!-- Get IRIS instance details from Embedded Python -->
  <Route Url="/versionpy" Method="get" Call="GetVersionPyResponse" />
  <!-- Synchronize a Patient with the FHIR repository -->
  <Route Url="/Patient" Method="post" Call="SyncPatient" />
  <!-- Project a source patient as an R4 FHIR Patient -->
  <Route Url="/Patient/:id" Method="get" Call="GetPatient" />
  <!-- Update the home address and upsert the Patient in FHIR -->
  <Route Url="/Patient/:id" Method="put" Call="PutPatient" />
  <!-- Delete the Patient from the FHIR repository -->
  <Route Url="/Patient/:id" Method="delete" Call="DeletePatient" />
</Routes>
}

/// Get IRIS instance details
ClassMethod GetVersion() As %Status
{
    Try {
        Do ##class(%REST.Impl).%SetContentType("application/json")
        If '##class(%REST.Impl).%CheckAccepts("application/json") {
            Try {
                Do ##class(fhirfoch.impl).%ReportRESTError(..#HTTP406NOTACCEPTABLE,$$$ERROR($$$RESTBadAccepts))
            } Catch {
                Do ##class(%REST.Impl).%ReportRESTError(..#HTTP406NOTACCEPTABLE,$$$ERROR($$$RESTBadAccepts))
            }
            Quit
        }
        Set response=##class(fhirfoch.impl).GetVersion()
        Do ##class(fhirfoch.impl).%WriteResponse(response)
    } Catch (ex) {
        Try {
            Do ##class(fhirfoch.impl).%ReportRESTError(..#HTTP500INTERNALSERVERERROR,ex.AsStatus(),$parameter("fhirfoch.impl","ExposeServerExceptions"))
        } Catch {
            Do ##class(%REST.Impl).%ReportRESTError(..#HTTP500INTERNALSERVERERROR,ex.AsStatus(),$parameter("fhirfoch.impl","ExposeServerExceptions"))
        }
    }
    Quit $$$OK
}

/// Get IRIS instance details from Embedded Python
ClassMethod GetVersionPyResponse() As %Status
{
    Try {
        Do ##class(%REST.Impl).%SetContentType("application/json")
        If '##class(%REST.Impl).%CheckAccepts("application/json") {
            Try {
                Do ##class(fhirfoch.impl).%ReportRESTError(..#HTTP406NOTACCEPTABLE,$$$ERROR($$$RESTBadAccepts))
            } Catch {
                Do ##class(%REST.Impl).%ReportRESTError(..#HTTP406NOTACCEPTABLE,$$$ERROR($$$RESTBadAccepts))
            }
            Quit
        }
        Set response=##class(fhirfoch.impl).GetVersionPyResponse()
        Do ##class(fhirfoch.impl).%WriteResponse(response)
    } Catch (ex) {
        Try {
            Do ##class(fhirfoch.impl).%ReportRESTError(..#HTTP500INTERNALSERVERERROR,ex.AsStatus(),$parameter("fhirfoch.impl","ExposeServerExceptions"))
        } Catch {
            Do ##class(%REST.Impl).%ReportRESTError(..#HTTP500INTERNALSERVERERROR,ex.AsStatus(),$parameter("fhirfoch.impl","ExposeServerExceptions"))
        }
    }
    Quit $$$OK
}

/// Synchronize a Patient with the FHIR repository
ClassMethod SyncPatient() As %Status
{
    Try {
        If $case(%request.ContentType,"application/fhir+json":0,"application/json":0,:1) {
            Try {
                Do ##class(fhirfoch.impl).%ReportRESTError(..#HTTP415UNSUPPORTEDMEDIATYPE,$$$ERROR($$$RESTContentType,%request.ContentType))
            } Catch {
                Do ##class(%REST.Impl).%ReportRESTError(..#HTTP415UNSUPPORTEDMEDIATYPE,$$$ERROR($$$RESTContentType,%request.ContentType))
            }
            Quit
        }
        Do ##class(%REST.Impl).%SetContentType("application/fhir+json")
        If '##class(%REST.Impl).%CheckAccepts("application/fhir+json") {
            Try {
                Do ##class(fhirfoch.impl).%ReportRESTError(..#HTTP406NOTACCEPTABLE,$$$ERROR($$$RESTBadAccepts))
            } Catch {
                Do ##class(%REST.Impl).%ReportRESTError(..#HTTP406NOTACCEPTABLE,$$$ERROR($$$RESTBadAccepts))
            }
            Quit
        }
        If '$isobject(%request.Content) Do ##class(%REST.Impl).%ReportRESTError(..#HTTP400BADREQUEST,$$$ERROR($$$RESTRequired,"body")) Quit
        Set pbody=%request.Content
        Set ptarget=$Get(%request.Data("target",1))
        Set response=##class(fhirfoch.impl).SyncPatient(pbody,ptarget)
        Do ##class(fhirfoch.impl).%WriteResponse(response)
    } Catch (ex) {
        Try {
            Do ##class(fhirfoch.impl).%ReportRESTError(..#HTTP500INTERNALSERVERERROR,ex.AsStatus(),$parameter("fhirfoch.impl","ExposeServerExceptions"))
        } Catch {
            Do ##class(%REST.Impl).%ReportRESTError(..#HTTP500INTERNALSERVERERROR,ex.AsStatus(),$parameter("fhirfoch.impl","ExposeServerExceptions"))
        }
    }
    Quit $$$OK
}

/// Project a source patient as an R4 FHIR Patient
ClassMethod GetPatient(pid As %String) As %Status
{
    Try {
        Do ##class(%REST.Impl).%SetContentType("application/fhir+json")
        If '##class(%REST.Impl).%CheckAccepts("application/fhir+json") {
            Try {
                Do ##class(fhirfoch.impl).%ReportRESTError(..#HTTP406NOTACCEPTABLE,$$$ERROR($$$RESTBadAccepts))
            } Catch {
                Do ##class(%REST.Impl).%ReportRESTError(..#HTTP406NOTACCEPTABLE,$$$ERROR($$$RESTBadAccepts))
            }
            Quit
        }
        Set response=##class(fhirfoch.impl).GetPatient(pid)
        Do ##class(fhirfoch.impl).%WriteResponse(response)
    } Catch (ex) {
        Try {
            Do ##class(fhirfoch.impl).%ReportRESTError(..#HTTP500INTERNALSERVERERROR,ex.AsStatus(),$parameter("fhirfoch.impl","ExposeServerExceptions"))
        } Catch {
            Do ##class(%REST.Impl).%ReportRESTError(..#HTTP500INTERNALSERVERERROR,ex.AsStatus(),$parameter("fhirfoch.impl","ExposeServerExceptions"))
        }
    }
    Quit $$$OK
}

/// Update the home address and upsert the Patient in FHIR
ClassMethod PutPatient(pid As %String) As %Status
{
    Try {
        If $case(%request.ContentType,"application/fhir+json":0,"application/json":0,:1) {
            Try {
                Do ##class(fhirfoch.impl).%ReportRESTError(..#HTTP415UNSUPPORTEDMEDIATYPE,$$$ERROR($$$RESTContentType,%request.ContentType))
            } Catch {
                Do ##class(%REST.Impl).%ReportRESTError(..#HTTP415UNSUPPORTEDMEDIATYPE,$$$ERROR($$$RESTContentType,%request.ContentType))
            }
            Quit
        }
        Do ##class(%REST.Impl).%SetContentType("application/fhir+json")
        If '##class(%REST.Impl).%CheckAccepts("application/fhir+json") {
            Try {
                Do ##class(fhirfoch.impl).%ReportRESTError(..#HTTP406NOTACCEPTABLE,$$$ERROR($$$RESTBadAccepts))
            } Catch {
                Do ##class(%REST.Impl).%ReportRESTError(..#HTTP406NOTACCEPTABLE,$$$ERROR($$$RESTBadAccepts))
            }
            Quit
        }
        If '$isobject(%request.Content) Do ##class(%REST.Impl).%ReportRESTError(..#HTTP400BADREQUEST,$$$ERROR($$$RESTRequired,"body")) Quit
        Set pbody=%request.Content
        Set ptarget=$Get(%request.Data("target",1))
        Set response=##class(fhirfoch.impl).PutPatient(pid,pbody,ptarget)
        Do ##class(fhirfoch.impl).%WriteResponse(response)
    } Catch (ex) {
        Try {
            Do ##class(fhirfoch.impl).%ReportRESTError(..#HTTP500INTERNALSERVERERROR,ex.AsStatus(),$parameter("fhirfoch.impl","ExposeServerExceptions"))
        } Catch {
            Do ##class(%REST.Impl).%ReportRESTError(..#HTTP500INTERNALSERVERERROR,ex.AsStatus(),$parameter("fhirfoch.impl","ExposeServerExceptions"))
        }
    }
    Quit $$$OK
}

/// Delete the Patient from the FHIR repository
ClassMethod DeletePatient(pid As %String) As %Status
{
    Try {
        Do ##class(%REST.Impl).%SetContentType("application/fhir+json")
        If '##class(%REST.Impl).%CheckAccepts("application/fhir+json") {
            Try {
                Do ##class(fhirfoch.impl).%ReportRESTError(..#HTTP406NOTACCEPTABLE,$$$ERROR($$$RESTBadAccepts))
            } Catch {
                Do ##class(%REST.Impl).%ReportRESTError(..#HTTP406NOTACCEPTABLE,$$$ERROR($$$RESTBadAccepts))
            }
            Quit
        }
        Set response=##class(fhirfoch.impl).DeletePatient(pid)
        Do ##class(fhirfoch.impl).%WriteResponse(response)
    } Catch (ex) {
        Try {
            Do ##class(fhirfoch.impl).%ReportRESTError(..#HTTP500INTERNALSERVERERROR,ex.AsStatus(),$parameter("fhirfoch.impl","ExposeServerExceptions"))
        } Catch {
            Do ##class(%REST.Impl).%ReportRESTError(..#HTTP500INTERNALSERVERERROR,ex.AsStatus(),$parameter("fhirfoch.impl","ExposeServerExceptions"))
        }
    }
    Quit $$$OK
}

}
