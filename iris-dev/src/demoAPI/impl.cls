Class demoAPI.impl Extends %REST.Impl [ ProcedureBlock ]
{

Parameter ExposeServerExceptions = 1;

ClassMethod AddDocument(body As %DynamicObject) As %DynamicObject
{
    return ##class(Demo.VectorAPIImpl).AddDocumentWrapper(body)
}

ClassMethod GetAllDocuments() As %DynamicObject
{
    return ##class(Demo.VectorAPIImpl).GetAllDocumentsWrapper()
}

ClassMethod DeleteDocument(uid As %String) As %DynamicObject
{
    return ##class(Demo.VectorAPIImpl).DeleteDocumentWrapper(uid)
}

ClassMethod SearchDocuments(body As %DynamicObject) As %DynamicObject
{
    return ##class(Demo.VectorAPIImpl).SearchWrapper(body)
}

}
