Class supervision.messageLog Extends Ens.BusinessOperation
{

Property Label As %String(MAXLEN = 255) [ InitialExpression = "MESSAGE FROM INTEROP PRODUCTION" ];

Parameter SETTINGS = "Label:advanced";

Method log(pRequest As Ens.AlertRequest, Output pResponse As %Persistent) As %Status
{
    set sc=$$$OK

    $$$TRACE("ALERT TEXT:" _ pRequest.AlertText)

    set sc = ##class(%SYS.System).WriteToConsoleLog("<<" _ ..Label _" in " _ $NAMESPACE _ " >> "  _ pRequest.AlertText,,1)

	return sc
}

XData MessageMap
{
<MapItems>
    <MapItem MessageType="Ens.AlertRequest">
        <Method>log</Method>
    </MapItem>
</MapItems>
}

}
