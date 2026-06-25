Class common.bi.utils [ Abstract ]
{

/// Nom du CUBE à reconstruire
Parameter cubeName = "HL7v2Patient";

/// This callback method is invoked by the <METHOD>%Save</METHOD> method to 
/// provide notification that the object is being saved. It is called after 
/// the object's data has been successfully written to disk.
/// 
/// <P><VAR>insert</VAR> will be set to 1 if this object is being saved for the first time.
/// 
/// <P>If this method returns an error then the call to <METHOD>%Save</METHOD> will fail.
Method %OnAfterSave(insert As %Boolean) As %Status [ Private, ServerOnly = 1 ]
{
	if ##class(%Dictionary.ClassDefinition).%ExistsId("%DeepSee.Utils") {
		do ##class(%DeepSee.Utils).%ProcessFact(..#cubeName,..%Id())
	}
	Quit $$$OK
}

/// This callback method is invoked by the <METHOD>%Delete</METHOD> method to 
/// provide notification that the object specified by <VAR>oid</VAR> has been deleted.
/// The callback occurs immediately after %DeleteData has been called. If %DeleteData returns
/// an error then %OnAfterDelete is not called.
/// 
/// <P>If %OnAfterDelete returns an error (%Status) then the transaction is rolled back.
ClassMethod %OnAfterDelete(oid As %ObjectIdentity) As %Status [ Private, ServerOnly = 1 ]
{
	if ##class(%Dictionary.ClassDefinition).%ExistsId("%DeepSee.Utils") {
		do ##class(%DeepSee.Utils).%DeleteFact(..#cubeName,oid)
	}
	Quit $$$OK
}

Trigger AfterDeleteTrigger [ Event = DELETE, Time = AFTER ]
{
	if ##class(%Dictionary.ClassDefinition).%ExistsId("%DeepSee.Utils") {
		do ##class(%DeepSee.Utils).%DeleteFact(..#cubeName,{ID})
	}
}

Trigger AfterInsertTrigger [ Event = INSERT, Time = AFTER ]
{
	if ##class(%Dictionary.ClassDefinition).%ExistsId("%DeepSee.Utils") {
		do ##class(%DeepSee.Utils).%ProcessFact(..#cubeName,{ID})
	}
}

Trigger AfterUpdateTrigger [ Event = UPDATE, Time = AFTER ]
{
	if ##class(%Dictionary.ClassDefinition).%ExistsId("%DeepSee.Utils") {
		do ##class(%DeepSee.Utils).%ProcessFact(..#cubeName,{ID})
	}
}

}
