/// Maps a data.patient (+ embedded data.address) into an R4 FHIR Patient resource
/// as a %DynamicObject.
Class training.fhir.PatientMapper
{

/// Identifier system for the French IPP (Identifiant Permanent du Patient).
Parameter IPPSYSTEM = "urn:oid:1.2.250.1.999.1";

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
    Set narrative = {}
    Set narrative.status = "generated"
    Set narrative.div = "<div xmlns=""http://www.w3.org/1999/xhtml"">Patient record</div>"
    Set res.text = narrative

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

    return res
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
    return addr
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

/// Insert or update data.patient from a FHIR Patient resource.
/// An empty pPatientId creates a row; otherwise the existing row is updated.
ClassMethod SaveToData(pResource As %DynamicObject, pPatientId As %String = "", Output pSavedId As %String) As %Status
{
    Set pSavedId = ""
    If '$IsObject(pResource) Quit $$$ERROR($$$GeneralError, "A FHIR Patient resource is required")
    If pResource.resourceType '= "Patient" Quit $$$ERROR($$$GeneralError, "resourceType must be Patient")

    If pPatientId = "" {
        Set ipp = ..IdentifierValue(pResource, ..#IPPSYSTEM)
        If ipp = "" Quit $$$ERROR($$$GeneralError, "The Patient IPP identifier is required")
        Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM data.patient WHERE IPP = ?", ipp)
        If rs.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, "Unable to check Patient IPP: "_rs.%Message)
        If rs.%Next() Quit $$$ERROR($$$GeneralError, "A data.patient row already exists for IPP '"_ipp_"'")
        Set patient = ##class(data.patient).%New()
    } Else {
        Set patient = ##class(data.patient).%OpenId(pPatientId, , .sc)
        Quit:$$$ISERR(sc) sc
        If '$IsObject(patient) Quit $$$ERROR($$$GeneralError, "data.patient '"_pPatientId_"' not found")
        Set ipp = ..IdentifierValue(pResource, ..#IPPSYSTEM)
        If ipp = "" Set ipp = patient.IPP
        If (patient.IPP '= "") && (patient.IPP '= ipp) Quit $$$ERROR($$$GeneralError, "Patient IPP is immutable; expected '"_patient.IPP_"'")
    }

    Set patient.IPP = ipp
    Set ins = ..IdentifierValue(pResource, ..#INSSYSTEM)
    If ins '= "" Set patient.INS = ins
    Set ssn = ..IdentifierValue(pResource, ..#SSNSYSTEM)
    If ssn '= "" Set patient.SSN = ssn
    If pResource.%IsDefined("active") Set patient.status = $Select(pResource.active: "qualified", 1: "deleted")

    If $IsObject(pResource.name) {
        Set iterator = pResource.name.%GetIterator()
        While iterator.%GetNext(.key, .name) {
            If name.use = "maiden" {
                Set patient.birthName = name.family
            } ElseIf (name.use = "official") || (patient.lastName = "") {
                Set patient.lastName = name.family
                If $IsObject(name.given) Set patient.firstName = name.given.%Get(0)
            }
        }
    }

    If $IsObject(pResource.telecom) {
        Set iterator = pResource.telecom.%GetIterator()
        While iterator.%GetNext(.key, .telecom) {
            If telecom.system = "email" Set patient.email = telecom.value
            If (telecom.system = "phone") && (telecom.use = "mobile") Set patient.mobilePhone = telecom.value
            If (telecom.system = "phone") && (telecom.use = "home") Set patient.phone = telecom.value
            If (telecom.system = "phone") && (telecom.use = "temp") Set patient.otherPhone = telecom.value
        }
    }

    If pResource.%IsDefined("gender") Set patient.sex = $Case(pResource.gender, "male": 1, "female": 2, "other": 3, : "")
    If pResource.%IsDefined("birthDate") Set patient.DOB = $ZDateH(pResource.birthDate, 3)
    If pResource.%IsDefined("deceasedDateTime") {
        Set patient.DOD = $ZDateH($Extract(pResource.deceasedDateTime, 1, 10), 3)
    } ElseIf pResource.%IsDefined("deceasedBoolean"), 'pResource.deceasedBoolean {
        Set patient.DOD = ""
    }

    If $IsObject(pResource.address), pResource.address.%Size() > 0 {
        Set address = pResource.address.%Get(0)
        Set iterator = pResource.address.%GetIterator()
        While iterator.%GetNext(.key, .candidate) {
            If candidate.use = "home" Set address = candidate Quit
        }
        Set patient.homeAddress = ..AddressFromFHIR(address)
    }

    If $IsObject(pResource.extension) {
        Set iterator = pResource.extension.%GetIterator()
        While iterator.%GetNext(.key, .extension) {
            If (extension.url = "http://hl7.org/fhir/StructureDefinition/patient-birthPlace") && $IsObject(extension.valueAddress) {
                Set patient.birthPlace = ..AddressFromFHIR(extension.valueAddress)
                Quit
            }
        }
    }

    Set patient.updatedAt = $ZDateTime($Horolog, 3)
    Set sc = patient.%Save()
    Quit:$$$ISERR(sc) sc
    Set pSavedId = patient.%Id()
    Quit $$$OK
}

/// Return an identifier value for the requested FHIR naming system.
ClassMethod IdentifierValue(pResource As %DynamicObject, pSystem As %String) As %String
{
    If '$IsObject(pResource.identifier) Quit ""
    Set value = ""
    Set iterator = pResource.identifier.%GetIterator()
    While iterator.%GetNext(.key, .identifier) {
        If identifier.system = pSystem Set value = identifier.value Quit
    }
    Quit value
}

/// Convert a FHIR Address object into data.address.
ClassMethod AddressFromFHIR(pAddress As %DynamicObject) As data.address
{
    Set address = ##class(data.address).%New()
    If $IsObject(pAddress.line) {
        Set address.Street = pAddress.line.%Get(0)
        Set address.RecipientComplement = pAddress.line.%Get(1)
        Set address.GeographicComplement = pAddress.line.%Get(2)
        Set address.LocalityPOBox = pAddress.line.%Get(3)
    }
    If pAddress.%IsDefined("city") Set address.City = pAddress.city
    If pAddress.%IsDefined("postalCode") Set address.PostalCode = pAddress.postalCode
    If pAddress.%IsDefined("country") Set address.Country = pAddress.country
    Quit address
}

}
