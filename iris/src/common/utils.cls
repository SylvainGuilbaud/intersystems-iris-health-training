Class common.utils
{

ClassMethod version() As %String [ Language = python ]
{
import iris
current_namespace = iris.cls("%SYSTEM.SYS").NameSpace()
iris.system.Process.SetNamespace("USER")
version = iris.gref("^VERSION").get()
iris.system.Process.SetNamespace(current_namespace)
return version
}

/// Conversion de secondes en Heures:Minutes:Secondes
ClassMethod hms(secondes As %Integer) As %Status [ Language = python ]
{
def secondes_vers_hms(secondes):
    heures = secondes // 3600
    minutes = (secondes % 3600) // 60
    secondes_restantes = secondes % 60
    return f"{heures:02d}:{minutes:02d}:{secondes_restantes:02d}"
return secondes_vers_hms(secondes)
}

/// Description
ClassMethod addLookupTableEntry(TableName, KeyName, DataValue) As %Status
{
    set sc = $$$OK
    set entry = ##class(Ens.Util.LookupTable).%New()
    set entry.TableName = TableName
    set entry.KeyName = KeyName
    set entry.DataValue = DataValue
    set sc = entry.%Save()
    return sc
}

}
