import os
import json
import uuid

import iris
from openai import AzureOpenAI


class VectorSearch:

    def __init__(self, table_name="Demo_Vector.Document", model="text-embedding-3-large"):
        self.table_name = table_name
        self.model = model
        self.client = AzureOpenAI(
            api_key=os.environ["AZURE_OPENAI_API_KEY"],
            azure_endpoint=os.environ["AZURE_OPENAI_ENDPOINT"],
            api_version=os.environ.get("AZURE_OPENAI_API_VERSION", "2024-12-01-preview"),
        )

    def _embed(self, text):
        deployment = os.environ.get("AZURE_OPENAI_EMBEDDING_DEPLOYMENT", self.model)
        response = self.client.embeddings.create(input=text, model=deployment)
        return response.data[0].embedding

    def add_document(self, text, metadata=None):
        uid = str(uuid.uuid4())[:40]
        embedding = self._embed(text)
        metadata_str = json.dumps(metadata) if metadata else "{}"

        sql = (
            f"INSERT INTO {self.table_name} "
            f"(uid, document, embedding, timestamp, metadata) "
            f"VALUES (?, ?, TO_VECTOR(?,DOUBLE), CURRENT_TIMESTAMP, ?)"
        )
        stmt = iris.sql.prepare(sql)
        stmt.execute(uid, text, str(embedding), metadata_str)
        return uid

    def search(self, query, k=5, threshold=0.3):
        query_embedding = self._embed(query)
        embedding_str = str(query_embedding)

        sql = (
            f"SELECT TOP ? uid, document, metadata, "
            f"VECTOR_DOT_PRODUCT(embedding, TO_VECTOR(?,DOUBLE)) AS score "
            f"FROM {self.table_name} "
            f"WHERE VECTOR_DOT_PRODUCT(embedding, TO_VECTOR(?,DOUBLE)) > ? "
            f"ORDER BY VECTOR_DOT_PRODUCT(embedding, TO_VECTOR(?,DOUBLE)) DESC"
        )
        stmt = iris.sql.prepare(sql)
        rs = stmt.execute(k, embedding_str, embedding_str, threshold, embedding_str)

        results = []
        for row in rs:
            results.append({
                "uid": row[0],
                "document": row[1],
                "metadata": json.loads(row[2]) if row[2] else {},
                "score": row[3],
            })
        return results

    def get_all(self):
        sql = f"SELECT uid, document, metadata, timestamp FROM {self.table_name} ORDER BY timestamp DESC"
        rs = iris.sql.exec(sql)

        results = []
        for row in rs:
            results.append({
                "uid": row[0],
                "document": row[1],
                "metadata": json.loads(row[2]) if row[2] else {},
                "timestamp": str(row[3]) if row[3] else None,
            })
        return results

    def delete(self, uid):
        sql = f"DELETE FROM {self.table_name} WHERE uid = ?"
        stmt = iris.sql.prepare(sql)
        stmt.execute(uid)
        return True
