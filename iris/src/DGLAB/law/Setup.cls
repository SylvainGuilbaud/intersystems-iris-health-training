Include Ensemble

/// Adds the IHE LAW (Laboratory Analytical Workflow) simulator items to an existing production.
/// The production definition of the DGLAB namespace is not stored in the sources, so the items are
/// merged in the production (idempotent: running it again replaces the LAW items by their current definition).
/// <example>
/// do ##class(DGLAB.law.Setup).AddToProduction("DGLABPKG.FoundationProduction")
/// </example>
/// The very same &lt;Item&gt; definitions are copied in TRAININGPKG.FoundationProduction.
Class DGLAB.law.Setup Extends %RegisteredObject
{

/// Production items of the IHE LAW simulator.
/// Every service that listens has its own port, inside the 9000-9200 range published by the dev container:
/// HTTP 9011 (LAB-27), 9012 (LAB-28), 9013 (LAB-29) and MLLP 9010. The default HTTP port 9980 is already taken
/// by "LAB RESULT from DGLAB - HTTP". TRAININGPKG.FoundationProduction runs in the same instance and
/// uses 9021-9023 and 9020 instead, so that both productions can run at the same time.
XData Items
{
<Items>
  <Item Name="LAW Analyzer Manager" Category="IHE LAW" ClassName="DGLAB.law.AnalyzerManager" PoolSize="1" Enabled="true" Foreground="false" Comment="IHE LAW simulator: Analyzer Manager for LAB-27 and LAB-29, Automate for LAB-28" LogTraceEvents="true" Schedule="">
    <Setting Target="Host" Name="AwosBroadcastTarget">LAW AWOS Broadcast to Analyzer - FILE</Setting>
  </Item>
  <Item Name="LAW AWOS Broadcast to Analyzer - FILE" Category="IHE LAW" ClassName="EnsLib.HL7.Operation.FileOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="LAB-28 AWOS Broadcast (OML^O33) written to files; replace by a TCP/HTTP operation to reach a real analyzer" LogTraceEvents="true" Schedule="">
    <Setting Target="Adapter" Name="FilePath">/data/HL7/LAW/out/</Setting>
    <Setting Target="Host" Name="Filename">OML_O33_%Q.hl7</Setting>
  </Item>
  <Item Name="LAW LAB-27 Query for AWOS - HTTP" Category="IHE LAW" ClassName="EnsLib.HL7.Service.HTTPService" PoolSize="1" Enabled="true" Foreground="false" Comment="LAB-27 Query for AWOS: QBP^Q11 answered by RSP^K11" LogTraceEvents="true" Schedule="">
    <Setting Target="Adapter" Name="Port">9011</Setting>
    <Setting Target="Host" Name="TargetConfigNames">LAW Analyzer Manager</Setting>
    <Setting Target="Host" Name="AckMode">App</Setting>
    <Setting Target="Host" Name="MessageSchemaCategory">2.5.1</Setting>
    <Setting Target="Host" Name="AddNackERR">1</Setting>
    <Setting Target="Host" Name="EnableStandardRequests">1</Setting>
  </Item>
  <Item Name="LAW LAB-28 AWOS Broadcast - HTTP" Category="IHE LAW" ClassName="EnsLib.HL7.Service.HTTPService" PoolSize="1" Enabled="true" Foreground="false" Comment="LAB-28 AWOS Broadcast: OML^O33 answered by ORL^O34" LogTraceEvents="true" Schedule="">
    <Setting Target="Adapter" Name="Port">9012</Setting>
    <Setting Target="Host" Name="TargetConfigNames">LAW Analyzer Manager</Setting>
    <Setting Target="Host" Name="AckMode">App</Setting>
    <Setting Target="Host" Name="MessageSchemaCategory">2.5.1</Setting>
    <Setting Target="Host" Name="AddNackERR">1</Setting>
    <Setting Target="Host" Name="EnableStandardRequests">1</Setting>
  </Item>
  <Item Name="LAW LAB-29 AWOS Status Change - HTTP" Category="IHE LAW" ClassName="EnsLib.HL7.Service.HTTPService" PoolSize="1" Enabled="true" Foreground="false" Comment="LAB-29 AWOS Status Change: OUL^R22 answered by ACK" LogTraceEvents="true" Schedule="">
    <Setting Target="Adapter" Name="Port">9013</Setting>
    <Setting Target="Host" Name="TargetConfigNames">LAW Analyzer Manager</Setting>
    <Setting Target="Host" Name="AckMode">App</Setting>
    <Setting Target="Host" Name="MessageSchemaCategory">2.5.1</Setting>
    <Setting Target="Host" Name="AddNackERR">1</Setting>
    <Setting Target="Host" Name="EnableStandardRequests">1</Setting>
  </Item>
  <Item Name="LAW LAB-27/28/29 - MLLP" Category="IHE LAW" ClassName="EnsLib.HL7.Service.TCPService" PoolSize="1" Enabled="true" Foreground="false" Comment="IHE LAW over MLLP: QBP^Q11, OML^O33 and OUL^R22 on a single port" LogTraceEvents="true" Schedule="">
    <Setting Target="Adapter" Name="Port">9010</Setting>
    <Setting Target="Adapter" Name="JobPerConnection">1</Setting>
    <Setting Target="Host" Name="TargetConfigNames">LAW Analyzer Manager</Setting>
    <Setting Target="Host" Name="AckMode">App</Setting>
    <Setting Target="Host" Name="MessageSchemaCategory">2.5.1</Setting>
    <Setting Target="Host" Name="AddNackERR">1</Setting>
  </Item>
</Items>
}

/// Adds the LAW items to the production pProduction (and refreshes the ones already there). When pUpdate is 1 and the production
/// is running, the running production is updated.
ClassMethod AddToProduction(pProduction As %String, pUpdate As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tProd = ##class(Ens.Config.Production).%OpenId(pProduction)
		If '$IsObject(tProd) {
			Set tSC = $$$ERROR($$$GeneralError, "Production " _ pProduction _ " not found in namespace " _ $Namespace)
			Quit
		}

		Set tXData = ##class(%Dictionary.CompiledXData).%OpenId($ClassName() _ "||Items")
		Set tReader = ##class(%XML.Reader).%New()
		Set tSC = tReader.OpenStream(tXData.Data)
		Quit:$$$ISERR(tSC)
		Do tReader.Correlate("Item", "Ens.Config.Item")

		Do ..EnsureOutputDirectory()

		Set tAdded = 0
		While tReader.Next(.tItem, .tSC) {
			// LAW items are owned by this class: an existing one is replaced by the current definition
			For i = tProd.Items.Count():-1:1 {
				If tProd.Items.GetAt(i).Name = tItem.Name {
					Do tProd.Items.RemoveAt(i)
					Write "Replaced ", tItem.Name, !
					Quit
				}
			}
			Do tProd.Items.Insert(tItem)
			Set tAdded = tAdded + 1
		}
		Quit:$$$ISERR(tSC)

		If tAdded {
			Set tSC = tProd.%Save()
			Quit:$$$ISERR(tSC)
			Set tSC = tProd.SaveToClass()
			Quit:$$$ISERR(tSC)
			Set tSC = $System.OBJ.Compile(pProduction, "ck-d")
			Quit:$$$ISERR(tSC)
		}
		Write tAdded, " item(s) added or replaced in ", pProduction, !

		// Release the production definition before updating: a stale open reference makes
		// Ens.Director fail with <INVALID OREF> in hasDisabledActorProcess
		Set (tProd, tReader, tItem, tXData) = ""
		If pUpdate && tAdded && ##class(Ens.Director).IsProductionRunning(pProduction) {
			Set tSC = ##class(Ens.Director).UpdateProduction()
		}
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

/// Creates the folder where the OML^O33 broadcast of the LAB-28 file operation is written
ClassMethod EnsureOutputDirectory(pDirectory As %String = "/data/HL7/LAW/out/") As %Boolean
{
	Quit ##class(%File).CreateDirectoryChain(pDirectory)
}

/// Adds the LAW items to every production of the current namespace
ClassMethod Install(pUpdate As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.ClassDefinition WHERE Super [ 'Ens.Production'")
	If tRS.%SQLCODE < 0 Quit $$$ERROR($$$SQLError, tRS.%SQLCODE, tRS.%Message)
	While tRS.%Next() {
		Set tName = tRS.%Get("Name")
		Continue:($Extract(tName, 1, 4) = "Ens.")
		Continue:($Extract(tName, 1, 3) = "HS.")
		Set tSC = $$$ADDSC(tSC, ..AddToProduction(tName, pUpdate))
	}
	Quit tSC
}

}
