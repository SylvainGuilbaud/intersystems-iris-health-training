# iris-health-training

This repository contains the production version and deployment-related setup for the IRIS project.

It creates a Docker Compose configuration to run both the IRIS database and the Web Gateway in a production-like environment. 

The IRIS instance is built from a custom Dockerfile that includes the necessary license key and application code to set up the REST API as defined in the `iris.script`. 
It creates a TRAINING namespace using 2 databases (one for data and one for code) with interoperability enabled and configures a CSP application at `/csp/training` with the appropriate dispatch class.
The application is enabled for DeepSee to allow for analytics capabilities.

It installs the ZPM package manager and uses it to enable the `webterminal`, `swagger-ui`, and `classexplorer` packages.

The Web Gateway is set up to route requests to this application, allowing for secure access to the REST API.

## Docker Compose

The `docker-compose.yml` defines two services:

### `iris`
- Built from the `iris/` directory using `containers.intersystems.com/intersystems/iris:latest-em` as the base image.
- Exposes the IRIS SuperServer port 1972 on the host via `$IRIS_PORT`.
- Mounts `databases_iris-health-training` as the IRIS data directory and `iris/key/iris.key` (read-only) as the license key.
- Mounts `journal_iris-health-training` and `journal2_iris-health-training` for IRIS transactional journaling.
- Mounts `WIJ_iris-health-training` for the Write-Image Journaling (WIJ) directory.
- Mounts `/iris/python/iris_python_demo` for Python code.
- Mounts `/iris/src` in `/code` for ObjectScript code and `/data` for any additional data files.
- Mounts `merge.cpf` to `/merge.cpf` to apply custom CPF settings on startup.
- Timezone is set to `Europe/Paris`.
- Restarts automatically unless manually stopped.

### `webgateway`
- Uses `containers.intersystems.com/intersystems/webgateway:latest-em` directly (no custom build).
- Depends on the `iris` service being started first.
- Exposes HTTP on `$WEBGATEWAY_PORT_HTTP` (→ 80) and HTTPS on `$WEBGATEWAY_PORT_HTTPS` (→ 443).
- Mounts `./webgateway/` for CSP gateway configuration (`CSP.conf` and `CSP.ini`).
- Restarts automatically unless manually stopped.

Both services share the default Docker network. Port values are configured via environment variables (e.g. in a `.env` file).

## BEFORE YOU START
- Ensure you have Docker and Docker Compose installed on your machine.
- Create a [`.env`](.env) file in the root of the project with the necessary environment variables (e.g. `IRIS_PORT`, `WEBGATEWAY_PORT_HTTP`, `WEBGATEWAY_PORT_HTTPS`).
- Place your IRIS license key in `iris/key/iris.key`
- Persistent data is stored in the `databases_iris-health-training` Docker volume, so ensure it has the appropriate permissions for Docker to read/write. The ./start.sh and ./stop.sh scripts will handle starting and stopping the services, but you can also use `docker compose` commands directly if needed. The [`./start.sh`](./start.sh) handles the permissions for the iris-data volume, ensuring that the IRIS container can access it properly.

## STARTING THE SERVICES
Run the following command in the root of the project to start both the IRIS and Web Gateway services:
```bash
./start.sh
```
This will build the IRIS image (if not already built) and start both containers. You can access the IRIS instance on the specified port and the Web Gateway on the configured HTTP/HTTPS ports.

## STOPPING THE SERVICES
To stop the running containers, use the following command:
```bash
./stop.sh
```

---

## Python Demo Module: Vector Similarity Search

This repo also includes an example Python module (`iris-python-demo`) that demonstrates how to develop Python code within IRIS using Embedded Python, REST APIs, and vector similarity search with Azure OpenAI embeddings.

### Additional Environment Variables

Add the following to your `.env` file for the Python demo module:

```env
OPENAI_API_KEY=<your-azure-openai-api-key>
OPENAI_ENDPOINT=https://<your-resource>.openai.azure.com/
OPENAI_API_VERSION=2024-12-01-preview
OPENAI_EMBEDDING_DEPLOYMENT=<your-embedding-deployment-name>
```

### Architecture

```
Client → Web Gateway (port 881) → IRIS REST API (ObjectScript) → Embedded Python → Python AI Logic
```

The module demonstrates:
- **REST API** defined via OpenAPI spec (`demoAPI/spec.cls`)
- **Embedded Python bridge** using `[Language = python]` methods (`Demo.VectorAPIImpl.cls`)
- **Pure Python logic** with pip dependencies (`iris_python_demo/vector.py`)
- **IRIS Vector table** with HNSW indexing (`Demo.Vector.Document.cls`)
- **Azure OpenAI embeddings** for similarity search (text-embedding-3-large, 3072 dimensions)

### Project Structure

```
iris/
├── module.xml              # ZPM module declaration
├── requirements.txt        # Python dependencies (openai, pydantic)
├── python/
│   └── iris_python_demo/
│       ├── __init__.py
│       └── vector.py       # VectorSearch class (Azure OpenAI + IRIS SQL)
└── src/
    ├── Demo/
    │   ├── VectorAPIImpl.cls   # Embedded Python bridge
    │   └── Vector/
    │       ├── Base.cls        # Abstract vector table with HNSW index
    │       └── Document.cls    # Concrete vector table
    └── demoAPI/
        ├── spec.cls            # OpenAPI route definitions
        └── impl.cls            # REST dispatch layer
```

### REST API Endpoints

Base URL: `http://localhost:2080/api/sc/demo/v1`

| Method | Path | Description |
|--------|------|-------------|
| POST | `/documents` | Add a document (generates embedding and stores it) |
| GET | `/documents` | List all stored documents |
| DELETE | `/documents/{uid}` | Delete a document by UID |
| POST | `/search` | Similarity search across stored documents |

Authentication: Basic Auth (`superuser` / `SYS`)

### Testing with Postman

Import the included Postman collection for quick testing:

[`IRIS Similarity Search Example APIs.postman_collection.json`](IRIS%20Similarity%20Search%20Example%20APIs.postman_collection.json)

### Testing with curl

```bash
# Add a document
curl -X POST http://localhost:2080/api/sc/demo/v1/documents \
  -H "Content-Type: application/json" -u superuser:SYS \
  -d '{"text": "IRIS supports native vector storage with HNSW indexing", "metadata": {"source": "docs"}}'

# Similarity search
curl -X POST http://localhost:2080/api/sc/demo/v1/search \
  -H "Content-Type: application/json" -u superuser:SYS \
  -d '{"query": "vector database features", "k": 5}'

# List all documents
curl http://localhost:2080/api/sc/demo/v1/documents -u superuser:SYS

# Delete a document (replace <uid> with actual uid from add response)
curl -X DELETE http://localhost:2080/api/sc/demo/v1/documents/<uid> -u superuser:SYS
```

### Development

#### Hot-Reload for Python

The `iris/python/iris_python_demo` directory is volume-mounted into the container. Changes to Python files are reflected immediately without rebuilding.

#### Rebuilding After Changes

- **Python code changes** (`iris/python/`): No rebuild needed (volume-mounted)
- **ObjectScript class changes** (`iris/src/`): InterSystems ObjectScript Extension Pack for VSCode can connect to IRIS to sync and compile ObjectScript classes
- **Dockerfile or dependency changes**: Rebuild required (`./start.sh`)
