/// Business service that reads data.patient rows and pushes each one, as a FHIR
/// Patient resource, to the FHIR server via training.fhir.PatientProcess.
/// Adapterless: trigger it on demand with SendAll() / SendOne().
Class training.fhir.PatientService Extends Ens.BusinessService
{

Parameter ADAPTER;

/// Config name of the process that performs the FHIR conversion and send.
Property TargetConfigName As Ens.DataType.ConfigName [ InitialExpression = "training.fhir.PatientProcess" ];

/// Optional verb override applied to every patient (empty = let the process decide).
Property DefaultHTTPMethod As %String(VALUELIST = ",POST,PUT,DELETE");

Parameter SETTINGS = "TargetConfigName:Basic:selector?context={Ens.ContextSearch/ProductionItems?targets=1&productionName=@productionId},DefaultHTTPMethod:Basic";

/// Required entry point; a manual ProcessInput call feeds all patients.
Method OnProcessInput(pInput As %RegisteredObject, Output pOutput As %RegisteredObject) As %Status
{
    Quit ..Feed()
}

/// Send every data.patient (optionally filtered by an SQL WHERE clause) to the FHIR server.
/// pMethod overrides the verb (POST/PUT/DELETE) for this run.
Method Feed(pMethod As %String = "", pFilter As %String = "") As %Status
{
    Set method = $Select(pMethod '= "": pMethod, 1: ..DefaultHTTPMethod)
    Set sql = "SELECT ID FROM data.patient"
    Set:(pFilter '= "") sql = sql _ " WHERE " _ pFilter

    Set rs = ##class(%SQL.Statement).%ExecDirect(, sql)
    If rs.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, "SQL error " _ rs.%SQLCODE _ ": " _ rs.%Message)

    Set (total, ok, ko) = 0
    While rs.%Next() {
        Set total = total + 1
        Set sc = ..SendOne(rs.%Get("ID"), method, .status)
        If $$$ISOK(sc) { Set ok = ok + 1 } Else { Set ko = ko + 1 }
    }
    $$$LOGINFO("FHIR patient feed complete: "_total_" patient(s), "_ok_" ok, "_ko_" error(s)")
    Quit $$$OK
}

/// Send a single data.patient id. Returns the FHIR HTTP status by reference.
Method SendOne(pPatientId As %String, pMethod As %String = "", Output pStatus As %String) As %Status
{
    Set pStatus = ""
    Set request = ##class(training.fhir.msg.PatientRequest).%New()
    Set request.PatientId = pPatientId
    Set:(pMethod '= "") request.HTTPMethod = pMethod

    Set sc = ..SendRequestSync(..TargetConfigName, request, .response)
    If $IsObject($Get(response)) Set pStatus = response.HTTPStatus
    Quit sc
}

/// Convenience: create the service on demand and feed all patients.
ClassMethod SendAll(pMethod As %String = "", pFilter As %String = "", pConfigName As %String = "training.fhir.PatientService") As %Status
{
    Set sc = ##class(Ens.Director).CreateBusinessService(pConfigName, .service)
    Quit:$$$ISERR(sc) sc
    Quit service.Feed(pMethod, pFilter)
}

/// Convenience: create the service on demand and send a single patient.
ClassMethod SendPatient(pPatientId As %String, pMethod As %String = "", pConfigName As %String = "training.fhir.PatientService") As %Status
{
    Set sc = ..SendPatientDetails(pPatientId, pMethod, .response, pConfigName)
    Quit sc
}

/// Send one patient and return the detailed interoperability response.
ClassMethod SendPatientDetails(pPatientId As %String, pMethod As %String = "", Output pResponse As training.fhir.msg.PatientResponse, pConfigName As %String = "training.fhir.PatientService") As %Status
{
    Set pResponse = ""
    Set sc = ##class(Ens.Director).CreateBusinessService(pConfigName, .service)
    Quit:$$$ISERR(sc) sc

    Set request = ##class(training.fhir.msg.PatientRequest).%New()
    Set request.PatientId = pPatientId
    Set:(pMethod '= "") request.HTTPMethod = pMethod
    Quit service.SendRequestSync(service.TargetConfigName, request, .pResponse)
}

}
