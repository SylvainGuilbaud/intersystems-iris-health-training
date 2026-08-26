/// REST facade over data.patient with R4 FHIR Patient representations.<br/>
/// Business logic class defined by OpenAPI in fhirfoch.spec<br/>
/// Updated Aug 26, 2026 14:35:03
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
        //set details.uptime = $ZDateTime($System.Process.GetUptime(), 3, 1, 3)
        set details.username = $USERNAME

        set namespaces = []
        
        do namespaces.%Push("toto")

        do namespaces.%Push("tata")

        do namespaces.%Push("titi")

        set details.namespaces = namespaces
        

        Set %response.Status = 200
        Set %response.ContentType = "application/json"
        Write details.%ToJSON()
        return details
}

/// Get IRIS instance details from Embedded Python
ClassMethod GetVersionPyResponse() As %DynamicObject
{
    //(Place business logic here)
    //Do ..%SetStatusCode(<HTTP_status_code>)
    //Do ..%SetHeader(<name>,<value>)
    //Quit (Place response here) ; response may be a string, stream or dynamic object
}

/// Returns the mapped Patient without persisting it to the FHIR repository.<br/>
/// The method arguments hold values for:<br/>
///     id, Internal data.patient source identifier<br/>
ClassMethod GetPatient(id As %String) As %Stream.Object
{
    //(Place business logic here)
    //Do ..%SetStatusCode(<HTTP_status_code>)
    //Do ..%SetHeader(<name>,<value>)
    //Quit (Place response here) ; response may be a string, stream or dynamic object
}

/// Selects POST or PUT according to whether the target Patient already exists.<br/>
/// The method arguments hold values for:<br/>
///     id, Internal data.patient source identifier<br/>
ClassMethod SyncPatient(id As %String) As %Stream.Object
{
    //(Place business logic here)
    //Do ..%SetStatusCode(<HTTP_status_code>)
    //Do ..%SetHeader(<name>,<value>)
    //Quit (Place response here) ; response may be a string, stream or dynamic object
}

/// The source id and IPP identifier are immutable. The first home address is imported into data.patient before an idempotent FHIR PUT.<br/>
/// The method arguments hold values for:<br/>
///     id, Internal data.patient source identifier<br/>
///     body, FHIR Patient carrying the editable home address.<br/>
ClassMethod PutPatient(id As %String, body As %Stream.Object) As %Stream.Object
{
    //(Place business logic here)
    //Do ..%SetStatusCode(<HTTP_status_code>)
    //Do ..%SetHeader(<name>,<value>)
    //Quit (Place response here) ; response may be a string, stream or dynamic object
}

/// Finds the target Patient by the source patient's IPP and deletes it. The data.patient source record is preserved.<br/>
/// The method arguments hold values for:<br/>
///     id, Internal data.patient source identifier<br/>
ClassMethod DeletePatient(id As %String) As %Stream.Object
{
    //(Place business logic here)
    //Do ..%SetStatusCode(<HTTP_status_code>)
    //Do ..%SetHeader(<name>,<value>)
    //Quit (Place response here) ; response may be a string, stream or dynamic object
}

}
