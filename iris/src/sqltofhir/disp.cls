/// API minimale avec deux endpoints: /sql/{id} retourne les données SQL brutes, /fhir/{id} retourne un Patient FHIR.
/// Dispatch class defined by RESTSpec in sqltofhir.spec
Class sqltofhir.disp Extends %CSP.REST [ GeneratedBy = sqltofhir.spec.cls, ProcedureBlock ]
{

/// The class containing the RESTSpec which generated this class
Parameter SpecificationClass = "sqltofhir.spec";

/// Ignore any writes done directly by the REST method.
Parameter IgnoreWrites = 1;

/// Default the Content-Type for this application.
Parameter CONTENTTYPE = "application/json";

/// By default convert the input stream to Unicode
Parameter CONVERTINPUTSTREAM = 1;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
  <!-- Récupérer les données patient au format SQL (JSON brut) -->
  <Route Url="/sql/:id" Method="get" Call="getSqlPatientById" />
  <!-- Récupérer le patient au format FHIR (Patient) -->
  <Route Url="/fhir/:id" Method="get" Call="getFhirPatientById" />
</Routes>
}

/// Récupérer les données patient au format SQL (JSON brut)
ClassMethod getSqlPatientById(pid As %String) As %Status
{
    Try {
        Do ##class(%REST.Impl).%SetContentType("application/json")
        If '##class(%REST.Impl).%CheckAccepts("application/json") {
            Try {
                Do ##class(sqltofhir.impl).%ReportRESTError(..#HTTP406NOTACCEPTABLE,$$$ERROR($$$RESTBadAccepts))
            } Catch {
                Do ##class(%REST.Impl).%ReportRESTError(..#HTTP406NOTACCEPTABLE,$$$ERROR($$$RESTBadAccepts))
            }
            Quit
        }
        Set response=##class(sqltofhir.impl).getSqlPatientById(pid)
        Do ##class(sqltofhir.impl).%WriteResponse(response)
    } Catch (ex) {
        Try {
            Do ##class(sqltofhir.impl).%ReportRESTError(..#HTTP500INTERNALSERVERERROR,ex.AsStatus(),$parameter("sqltofhir.impl","ExposeServerExceptions"))
        } Catch {
            Do ##class(%REST.Impl).%ReportRESTError(..#HTTP500INTERNALSERVERERROR,ex.AsStatus(),$parameter("sqltofhir.impl","ExposeServerExceptions"))
        }
    }
    Quit $$$OK
}

/// Récupérer le patient au format FHIR (Patient)
ClassMethod getFhirPatientById(pid As %String) As %Status
{
    Try {
        Do ##class(%REST.Impl).%SetContentType("application/fhir+json")
        If '##class(%REST.Impl).%CheckAccepts("application/fhir+json") {
            Try {
                Do ##class(sqltofhir.impl).%ReportRESTError(..#HTTP406NOTACCEPTABLE,$$$ERROR($$$RESTBadAccepts))
            } Catch {
                Do ##class(%REST.Impl).%ReportRESTError(..#HTTP406NOTACCEPTABLE,$$$ERROR($$$RESTBadAccepts))
            }
            Quit
        }
        Set response=##class(sqltofhir.impl).getFhirPatientById(pid)
        Do ##class(sqltofhir.impl).%WriteResponse(response)
    } Catch (ex) {
        Try {
            Do ##class(sqltofhir.impl).%ReportRESTError(..#HTTP500INTERNALSERVERERROR,ex.AsStatus(),$parameter("sqltofhir.impl","ExposeServerExceptions"))
        } Catch {
            Do ##class(%REST.Impl).%ReportRESTError(..#HTTP500INTERNALSERVERERROR,ex.AsStatus(),$parameter("sqltofhir.impl","ExposeServerExceptions"))
        }
    }
    Quit $$$OK
}

}
