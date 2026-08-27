Include %occStatus

Class weather.GeocodingOperation Extends Ens.BusinessOperation
{

Property Server As %String [ InitialExpression = "geocoding-api.open-meteo.com" ];

Property SSLConfiguration As %String [ InitialExpression = "BFC_SSL" ];

Parameter SETTINGS = "Server:Basic,SSLConfiguration:Basic";

Method Geocode(pRequest As weather.msg.GeocodingRequest, Output pResponse As weather.msg.GeocodingResponse) As %Status
{
    Set pResponse = ##class(weather.msg.GeocodingResponse).%New()
    If pRequest.City = "" Quit $$$OK

    Set query = pRequest.City

    Set request = ##class(%Net.HttpRequest).%New()
    Set request.Server = ..Server
    Set request.Https = 1
    Set request.SSLConfiguration = ..SSLConfiguration
    Set request.Timeout = 10
    Set path = "/v1/search?name="_##class(%CSP.Page).EscapeURL(query)_"&count=1&language=fr&format=json"
    Set sc = request.Get(path)
    Quit:$$$ISERR(sc) sc
    If request.HttpResponse.StatusCode '= 200 {
        Quit $$$ERROR($$$GeneralError, "Geocoding API returned HTTP "_request.HttpResponse.StatusCode)
    }

    Set payload = {}.%FromJSON(request.HttpResponse.Data)
    If '$IsObject(payload.results) || (payload.results.%Size() = 0) Quit $$$OK
    Set result = payload.results.%Get(0)
    Set pResponse.Found = 1
    Set pResponse.Name = result.name
    Set pResponse.Country = result.country
    Set pResponse.Latitude = result.latitude
    Set pResponse.Longitude = result.longitude
    Quit $$$OK
}

XData MessageMap
{
<MapItems>
    <MapItem MessageType="weather.msg.GeocodingRequest">
        <Method>Geocode</Method>
    </MapItem>
</MapItems>
}

}