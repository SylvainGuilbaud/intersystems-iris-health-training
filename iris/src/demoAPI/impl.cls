/// Example REST API demonstrating Embedded Python with vector search in IRIS<br/>
/// Business logic class defined by OpenAPI in demoAPI.spec<br/>
/// Updated Jun 16, 2026 16:35:28
Class demoAPI.impl Extends %REST.Impl [ ProcedureBlock ]
{

Parameter ExposeServerExceptions = 1;

/// Add a document with vector embedding<br/>
/// The method arguments hold values for:<br/>
///     body<br/>
ClassMethod AddDocument(body As %DynamicObject) As %DynamicObject
{
    return ##class(Demo.VectorAPIImpl).AddDocumentWrapper(body)
}

/// List all stored documents
ClassMethod GetAllDocuments() As %DynamicObject
{
    return ##class(Demo.VectorAPIImpl).GetAllDocumentsWrapper()
}

/// Delete a document by uid<br/>
/// The method arguments hold values for:<br/>
///     uid<br/>
ClassMethod DeleteDocument(uid As %String) As %DynamicObject
{
    return ##class(Demo.VectorAPIImpl).DeleteDocumentWrapper(uid)
}

/// Similarity search across stored documents<br/>
/// The method arguments hold values for:<br/>
///     body<br/>
ClassMethod SearchDocuments(body As %DynamicObject) As %DynamicObject
{
    return ##class(Demo.VectorAPIImpl).SearchWrapper(body)
}

}
