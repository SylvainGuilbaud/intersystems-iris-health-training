Class demoAPI.spec Extends %REST.Spec [ ProcedureBlock ]
{

XData OpenAPI [ MimeType = application/json ]
{
{
  "swagger": "2.0",
  "info": {
    "title": "IRIS Python Demo - Vector Search API",
    "version": "1.0.0",
    "description": "Example REST API demonstrating Embedded Python with vector search in IRIS"
  },
  "basePath": "/api/{$namespace}/demo/v1",
  "schemes": ["http"],
  "consumes": ["application/json"],
  "produces": ["application/json"],
  "paths": {
    "/documents": {
      "post": {
        "operationId": "AddDocument",
        "summary": "Add a document with vector embedding",
        "parameters": [{
          "in": "body",
          "name": "body",
          "required": true,
          "schema": { "$ref": "#/definitions/AddDocumentRequest" }
        }],
        "responses": {
          "201": { "description": "Document created successfully" },
          "400": { "description": "Bad request" },
          "500": { "description": "Internal server error" }
        }
      },
      "get": {
        "operationId": "GetAllDocuments",
        "summary": "List all stored documents",
        "responses": {
          "200": { "description": "List of documents" },
          "500": { "description": "Internal server error" }
        }
      }
    },
    "/documents/{uid}": {
      "delete": {
        "operationId": "DeleteDocument",
        "summary": "Delete a document by uid",
        "parameters": [{
          "in": "path",
          "name": "uid",
          "required": true,
          "type": "string"
        }],
        "responses": {
          "200": { "description": "Document deleted" },
          "400": { "description": "Bad request" },
          "500": { "description": "Internal server error" }
        }
      }
    },
    "/search": {
      "post": {
        "operationId": "SearchDocuments",
        "summary": "Similarity search across stored documents",
        "parameters": [{
          "in": "body",
          "name": "body",
          "required": true,
          "schema": { "$ref": "#/definitions/SearchRequest" }
        }],
        "responses": {
          "200": { "description": "Search results" },
          "400": { "description": "Bad request" },
          "500": { "description": "Internal server error" }
        }
      }
    }
  },
  "definitions": {
    "AddDocumentRequest": {
      "type": "object",
      "required": ["text"],
      "properties": {
        "text": { "type": "string", "description": "Document text to store and embed" },
        "metadata": { "type": "object", "description": "Optional metadata JSON" }
      }
    },
    "SearchRequest": {
      "type": "object",
      "required": ["query"],
      "properties": {
        "query": { "type": "string", "description": "Search query text" },
        "k": { "type": "integer", "default": 5, "description": "Number of results to return" }
      }
    }
  }
}
}

}
