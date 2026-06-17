Class adm.security Extends %RegisteredObject
{
classmethod setNewPassword(pUser As %String, pNewPassword As %String) As %Status
{
    set ns=$NAMESPACE
    zn "%SYS"
    set Properties("Password")=pNewPassword
    set sc = ##class(Security.Users).Modify(pUser,.Properties)
    zn ns
    return $$$OK
}
}