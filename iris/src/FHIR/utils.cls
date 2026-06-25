Class FHIR.utils
{

ClassMethod SetupFHIRServer(ns As %String, dir As %String = "/home/irisowner/dev") As %Status
{
    zn "HSLIB"
    set namespace=ns
    Set appKey = "/" _ $zcvt(ns,"L") _ "/fhir/r4"
    Set strategyClass = "HS.FHIRServer.Storage.Json.InteractionsStrategy"
    set metadataPackages = $lb("hl7.fhir.r4.core@4.0.1")
    Set metadataConfigKey = "HL7v40"

    //Install a Foundation namespace and change to it
    Do ##class(HS.Util.Installer.Foundation).Install(namespace)

    zn namespace

    // Install elements that are required for a FHIR-enabled namespace
    do ##class(HS.FHIRServer.Installer).InstallNamespace()

    // Install an instance of a FHIR Service into the current namespace
    if '##class(HS.FHIRServer.ServiceAdmin).EndpointExists(appKey) {
       do ##class(HS.FHIRServer.Installer).InstallInstance(appKey, strategyClass, metadataPackages)
    }

    set strategy = ##class(HS.FHIRServer.API.InteractionsStrategy).GetStrategyForEndpoint(appKey)
    set config = strategy.GetServiceConfigData()
    set config.DebugMode = 4
    set config.DefaultSearchPageSize = 1000
    set config.MaxSearchPageSize = 10000
    set config.MaxSearchResults = 10000
    do strategy.SaveServiceConfigData(config)

    //
    set cspConfig = ##class(HS.Util.RESTCSPConfig).URLIndexOpen(appKey)
    set cspConfig.ServiceConfigName = "HS.FHIRServer.Interop.Service"
    set cspConfig.AllowUnauthenticatedAccess = 1
    w cspConfig.%Save()
    //

    do $system.OBJ.Import(dir_"/src","cdk",.errors,1)
    zw $classmethod("Ens.Director", "SetAutoStart", "IRISAPP.production", 0)

    //
    
    set data=dir_"/data/fhir/"
    write !," ====== Load test data in "_ns_" from "_data
    set st=##class(HS.FHIRServer.Tools.DataLoader).SubmitResourceFiles(data, "FHIRServer", appKey)
    if 'st write $System.Status.GetErrorText(st)

    quit st
}

ClassMethod LoadPatientData(path, namespace, appKey) As %Status
{
    quit ##class(HS.FHIRServer.Tools.DataLoader).SubmitResourceFiles(path, namespace, appKey)
}

ClassMethod AddApp(ns = {$namespace}) As %Status
{
    set namespace=ns
    zn "%SYS"
    set webName = "/fhirUI"
    set webProperties("NameSpace") = namespace
    set webProperties("Enabled") = 1
    set webProperties("Path") = "/irisdev/app/fhirUI"
    set webProperties("AutheEnabled") = 64
    set webProperties("ServeFiles")=2
    set webProperties("Recurse")=1
    quit ##class(Security.Applications).Create(webName, .webProperties)
}

}
