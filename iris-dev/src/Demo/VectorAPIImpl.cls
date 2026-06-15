Class Demo.VectorAPIImpl Extends %REST.Impl [ ProcedureBlock ]
{

XData %import [ MimeType = application/python ]
{
import json
from iris_python_demo.vector import VectorSearch
}

ClassMethod AddDocumentWrapper(body As %DynamicObject) As %DynamicObject
{
    try {
        set text = body.%Get("text", "")
        if text = "" {
            do ..%SetStatusCode("400")
            return {"status": "error", "message": "Missing required field: text"}
        }

        set metadata = body.%Get("metadata")
        if $ISOBJECT(metadata) {
            set metadataStr = metadata.%ToJSON()
        } else {
            set metadataStr = "{}"
        }
        set responseStr = ..AddDocument(text, metadataStr)

        do ..%SetStatusCode("201")
        return ##class(%DynamicObject).%FromJSON(responseStr)
    } catch ex {
        do ..%SetStatusCode("500")
        return {"status": "error", "message": ($System.Status.GetErrorText(ex.AsStatus()))}
    }
}

ClassMethod AddDocument(text As %String, metadataJSON As %String) As %String [ Language = python ]
{
    vs = VectorSearch()
    metadata = json.loads(metadataJSON) if metadataJSON else {}
    uid = vs.add_document(text, metadata)
    return json.dumps({"status": "ok", "uid": uid})
}

ClassMethod SearchWrapper(body As %DynamicObject) As %DynamicObject
{
    try {
        set query = body.%Get("query", "")
        if query = "" {
            do ..%SetStatusCode("400")
            return {"status": "error", "message": "Missing required field: query"}
        }

        set k = body.%Get("k", 5)
        set responseStr = ..Search(query, k)

        do ..%SetStatusCode("200")
        return ##class(%DynamicObject).%FromJSON(responseStr)
    } catch ex {
        do ..%SetStatusCode("500")
        return {"status": "error", "message": ($System.Status.GetErrorText(ex.AsStatus()))}
    }
}

ClassMethod Search(query As %String, k As %Integer = 5) As %String [ Language = python ]
{
    vs = VectorSearch()
    results = vs.search(query, k=int(k))
    return json.dumps({"status": "ok", "results": results})
}

ClassMethod GetAllDocumentsWrapper() As %DynamicObject
{
    try {
        set responseStr = ..GetAllDocuments()
        do ..%SetStatusCode("200")
        return ##class(%DynamicObject).%FromJSON(responseStr)
    } catch ex {
        do ..%SetStatusCode("500")
        return {"status": "error", "message": ($System.Status.GetErrorText(ex.AsStatus()))}
    }
}

ClassMethod GetAllDocuments() As %String [ Language = python ]
{
    vs = VectorSearch()
    results = vs.get_all()
    return json.dumps({"status": "ok", "documents": results})
}

ClassMethod DeleteDocumentWrapper(uid As %String) As %DynamicObject
{
    try {
        if uid = "" {
            do ..%SetStatusCode("400")
            return {"status": "error", "message": "Missing required parameter: uid"}
        }

        set responseStr = ..DeleteDocument(uid)
        do ..%SetStatusCode("200")
        return ##class(%DynamicObject).%FromJSON(responseStr)
    } catch ex {
        do ..%SetStatusCode("500")
        return {"status": "error", "message": ($System.Status.GetErrorText(ex.AsStatus()))}
    }
}

ClassMethod DeleteDocument(uid As %String) As %String [ Language = python ]
{
    vs = VectorSearch()
    vs.delete(uid)
    return json.dumps({"status": "ok", "message": f"Document {uid} deleted"})
}

}
