Include %occStatus

Class weather.PatientProcess Extends Ens.BusinessProcess [ ClassType = persistent ]
{

Parameter ENRICHMENTURL = "https://github.com/SylvainGuilbaud/intersystems-iris-health-training/fhir/StructureDefinition/patient-environment";

Property GeocodingOperation As Ens.DataType.ConfigName [ InitialExpression = "weather.GeocodingOperation" ];

Property WeatherOperation As Ens.DataType.ConfigName [ InitialExpression = "weather.WeatherOperation" ];

Parameter SETTINGS = "GeocodingOperation:Basic:selector?context={Ens.ContextSearch/ProductionItems?targets=1&productionName=@productionId},WeatherOperation:Basic:selector?context={Ens.ContextSearch/ProductionItems?targets=1&productionName=@productionId}";

Method OnRequest(pRequest As weather.msg.PatientEnrichmentRequest, Output pResponse As weather.msg.PatientEnrichmentResponse) As %Status
{
    Set pResponse = ##class(weather.msg.PatientEnrichmentResponse).%New()
    Set patient = ##class(data.patient).%OpenId(pRequest.PatientId, , .sc)
    Quit:$$$ISERR(sc) sc
    If '$IsObject(patient) Quit $$$ERROR($$$GeneralError, "data.patient '"_pRequest.PatientId_"' not found")

    Set resource = ##class(training.fhir.PatientMapper).ToResource(pRequest.PatientId, 1, .sc)
    Quit:$$$ISERR(sc) sc
    Set enrichment = {"url": (..#ENRICHMENTURL), "extension": []}

    Set sc = ..EnrichLocation(patient.birthPlace, "birthPlace", .birthPlaceExtension)
    Quit:$$$ISERR(sc) sc
    If $IsObject(birthPlaceExtension) Do enrichment.extension.%Push(birthPlaceExtension)

    Set sc = ..EnrichLocation(patient.homeAddress, "home", .homeExtension)
    Quit:$$$ISERR(sc) sc
    If $IsObject(homeExtension) Do enrichment.extension.%Push(homeExtension)

    If enrichment.extension.%Size() > 0 {
        If '$IsObject(resource.extension) Set resource.extension = []
        Do resource.extension.%Push(enrichment)
    }

    Set stream = ##class(HS.SDA3.QuickStream).%New()
    Do stream.Write(resource.%ToJSON())
    Do stream.Flush()
    Set sc = stream.%Save()
    Quit:$$$ISERR(sc) sc
    Set pResponse.ResourceStreamId = stream.%Id()
    Quit $$$OK
}

Method EnrichLocation(pAddress As data.address, pRole As %String, Output pExtension As %DynamicObject) As %Status
{
    Set pExtension = ""
    If '$IsObject(pAddress) || (pAddress.City = "") Quit $$$OK

    Set geocodingRequest = ##class(weather.msg.GeocodingRequest).%New()
    Set geocodingRequest.City = pAddress.City
    Set geocodingRequest.PostalCode = pAddress.PostalCode
    Set geocodingRequest.Country = pAddress.Country
    Set sc = ..SendRequestSync(..GeocodingOperation, geocodingRequest, .geocodingResponse)
    Quit:$$$ISERR(sc) sc
    If '$IsObject(geocodingResponse) || 'geocodingResponse.Found {
        Quit $$$ERROR($$$GeneralError, "No geographic coordinates found for "_pRole_" city '"_pAddress.City_"'")
    }

    Set weatherRequest = ##class(weather.msg.WeatherRequest).%New()
    Set weatherRequest.Latitude = geocodingResponse.Latitude
    Set weatherRequest.Longitude = geocodingResponse.Longitude
    Set sc = ..SendRequestSync(..WeatherOperation, weatherRequest, .weatherResponse)
    Quit:$$$ISERR(sc) sc
    If '$IsObject(weatherResponse) Quit $$$ERROR($$$GeneralError, "No weather response for "_pRole_" city '"_pAddress.City_"'")

    Set details = []
    Do details.%Push({"url": "city", "valueString": (geocodingResponse.Name)})
    Do details.%Push({"url": "country", "valueString": (geocodingResponse.Country)})
    Set latitude = {"url": "latitude"}
    Do latitude.%Set("valueDecimal", geocodingResponse.Latitude, "number")
    Do details.%Push(latitude)
    Set longitude = {"url": "longitude"}
    Do longitude.%Set("valueDecimal", geocodingResponse.Longitude, "number")
    Do details.%Push(longitude)
    Set quantity = {"unit": (weatherResponse.Unit), "system": "http://unitsofmeasure.org", "code": "Cel"}
    Do quantity.%Set("value", weatherResponse.Temperature, "number")
    Do details.%Push({"url": "temperature", "valueQuantity": (quantity)})
    Do details.%Push({"url": "observedAt", "valueDateTime": (weatherResponse.ObservedAt)})
    Set pExtension = {"url": (pRole), "extension": (details)}
    Quit $$$OK
}

}