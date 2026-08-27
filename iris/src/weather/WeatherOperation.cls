Include %occStatus

Class weather.WeatherOperation Extends Ens.BusinessOperation
{

Property Server As %String [ InitialExpression = "api.open-meteo.com" ];

Property SSLConfiguration As %String [ InitialExpression = "BFC_SSL" ];

Parameter SETTINGS = "Server:Basic,SSLConfiguration:Basic";

Method CurrentWeather(pRequest As weather.msg.WeatherRequest, Output pResponse As weather.msg.WeatherResponse) As %Status
{
    Set pResponse = ##class(weather.msg.WeatherResponse).%New()
    Set request = ##class(%Net.HttpRequest).%New()
    Set request.Server = ..Server
    Set request.Https = 1
    Set request.SSLConfiguration = ..SSLConfiguration
    Set request.Timeout = 10
    Set path = "/v1/forecast?latitude="_pRequest.Latitude_"&longitude="_pRequest.Longitude_"&current=temperature_2m&timezone=GMT"
    Set sc = request.Get(path)
    Quit:$$$ISERR(sc) sc
    If request.HttpResponse.StatusCode '= 200 {
        Quit $$$ERROR($$$GeneralError, "Weather API returned HTTP "_request.HttpResponse.StatusCode)
    }

    Set payload = {}.%FromJSON(request.HttpResponse.Data)
    If '$IsObject(payload.current) Quit $$$ERROR($$$GeneralError, "Weather API response has no current observations")
    Set pResponse.Temperature = payload.current."temperature_2m"
    Set pResponse.Unit = payload."current_units"."temperature_2m"
    Set pResponse.ObservedAt = payload.current.time_"Z"
    Quit $$$OK
}

XData MessageMap
{
<MapItems>
    <MapItem MessageType="weather.msg.WeatherRequest">
        <Method>CurrentWeather</Method>
    </MapItem>
</MapItems>
}

}