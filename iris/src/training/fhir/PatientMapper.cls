/// Maps a data.patient (+ embedded data.address) into an R4 FHIR Patient resource
/// as a %DynamicObject.
Class training.fhir.PatientMapper
{

/// Identifier system for the French IPP (Identifiant Permanent du Patient).
Parameter IPPSYSTEM = "urn:oid:1.2.250.1.999.1.ipp";

/// Identifier system for the INS (Identité Nationale de Santé).
Parameter INSSYSTEM = "urn:oid:1.2.250.1.213.1.4.8";

/// Identifier system for the social security number (NIR).
Parameter SSNSYSTEM = "urn:oid:1.2.250.1.213.1.4.10";

/// Build the FHIR Patient resource for the given data.patient id.
/// When pIncludeId is true the resource carries a logical id derived from IPP
/// (used for PUT / upsert).
ClassMethod ToResource(pPatientId As %String, pIncludeId As %Boolean = 0, Output pStatus As %Status) As %DynamicObject
{
    Set pStatus = $$$OK
    Set patient = ##class(data.patient).%OpenId(pPatientId, , .pStatus)
    If '$IsObject(patient) {
        If $$$ISOK(pStatus) Set pStatus = $$$ERROR($$$GeneralError, "data.patient '"_pPatientId_"' not found")
        Quit ""
    }

    Set res = {"resourceType": "Patient"}

    If pIncludeId {
        Set res.id = ..LogicalId(patient.IPP)
    }

    // --- identifiers ---
    Set res.identifier = []
    If patient.IPP '= "" {
        Do res.identifier.%Push({"system": (..#IPPSYSTEM), "value": (patient.IPP)})
    }
    If patient.INS '= "" {
        Do res.identifier.%Push({"system": (..#INSSYSTEM), "value": (patient.INS)})
    }
    If patient.SSN '= "" {
        Do res.identifier.%Push({"system": (..#SSNSYSTEM), "value": (patient.SSN)})
    }

    // --- active flag (deleted patients are inactive) ---
    Do res.%Set("active", $Select(patient.status = "deleted": 0, 1: 1), "boolean")

    // --- names ---
    Set res.name = []
    If (patient.lastName '= "") || (patient.firstName '= "") {
        Set name = {"use": "official"}
        If patient.lastName '= "" Set name.family = patient.lastName
        If patient.firstName '= "" Set name.given = [(patient.firstName)]
        Do res.name.%Push(name)
    }
    If patient.birthName '= "" {
        Do res.name.%Push({"use": "maiden", "family": (patient.birthName)})
    }

    // --- telecom ---
    Set res.telecom = []
    If patient.email '= "" Do res.telecom.%Push({"system": "email", "value": (patient.email)})
    If patient.mobilePhone '= "" Do res.telecom.%Push({"system": "phone", "value": (patient.mobilePhone), "use": "mobile"})
    If patient.phone '= "" Do res.telecom.%Push({"system": "phone", "value": (patient.phone), "use": "home"})
    If patient.otherPhone '= "" Do res.telecom.%Push({"system": "phone", "value": (patient.otherPhone), "use": "temp"})

    // --- gender (1=M, 2=F, 3=I) ---
    Set res.gender = $Case(patient.sex, 1: "male", 2: "female", 3: "other", : "unknown")

    // --- birthDate / deceased ---
    If patient.DOB '= "" Set res.birthDate = $ZDate(patient.DOB, 3)
    If patient.DOD '= "" {
        Set res."deceasedDateTime" = $ZDate(patient.DOD, 3)
    } Else {
        Do res.%Set("deceasedBoolean", 0, "boolean")
    }

    // --- address (home) ---
    Set homeAddr = ..AddressToFHIR(patient.homeAddress, "home")
    If homeAddr '= "" {
        Set res.address = [(homeAddr)]
    }

    // --- birthplace extension ---
    Set birthAddr = ..AddressToFHIR(patient.birthPlace, "")
    If birthAddr '= "" {
        Set res.extension = [{"url": "http://hl7.org/fhir/StructureDefinition/patient-birthPlace", "valueAddress": (birthAddr)}]
    }

    Quit res
}

/// Convert a data.address into a FHIR Address %DynamicObject (or "" when empty).
ClassMethod AddressToFHIR(pAddress As data.address, pUse As %String = "") As %DynamicObject
{
    If '$IsObject(pAddress) Quit ""

    Set addr = {}
    If pUse '= "" Set addr.use = pUse

    Set lines = []
    For prop = "Street", "RecipientComplement", "GeographicComplement", "LocalityPOBox" {
        Set val = $ZStrip($Property(pAddress, prop), "<>W")
        If val '= "" Do lines.%Push(val)
    }
    If lines.%Size() > 0 Set addr.line = lines
    If $ZStrip(pAddress.City, "<>W") '= "" Set addr.city = pAddress.City
    If $ZStrip(pAddress.PostalCode, "<>W") '= "" Do addr.%Set("postalCode", pAddress.PostalCode, "string")
    If $ZStrip(pAddress.Country, "<>W") '= "" Set addr.country = pAddress.Country

    // Nothing meaningful to emit
    If (addr.%Size() = 0) || ((addr.%Size() = 1) && (pUse '= "")) Quit ""
    Quit addr
}

/// Sanitize an IPP into a valid FHIR logical id ([A-Za-z0-9-.]{1,64}).
ClassMethod LogicalId(pIPP As %String) As %String
{
    Set id = ""
    For i = 1:1:$Length(pIPP) {
        Set ch = $Extract(pIPP, i)
        If ch?1(1AN,1"-",1".") {
            Set id = id_ch
        } Else {
            Set id = id_"-"
        }
    }
    Quit $Extract(id, 1, 64)
}

}
