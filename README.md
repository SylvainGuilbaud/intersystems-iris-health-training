# iris-health-training

This repository contains the production version and deployment-related setup for the IRIS project.

It creates a Docker Compose configuration to run both the IRIS database and the Web Gateway in a production-like environment. 

The IRIS instance is built from a custom Dockerfile that includes the necessary license key and application code to set up the REST API as defined in the `iris.script`. 
It creates a TRAINING namespace using 2 databases (one for data and one for code) with interoperability enabled and configures a CSP application at `/csp/training` with the appropriate dispatch class.
The application is enabled for DeepSee to allow for analytics capabilities.

It installs the ZPM package manager and uses it to install the `swagger-ui` package.

The Web Gateway is set up to route requests to this application, allowing for secure access to the REST API.

## You can use the `docker-compose-local.yml` file to run the services in a local development environment. 
This configuration uses Docker volumes for persistent storage of IRIS data and journals, allowing you to stop and start the containers without losing your data.

This script can be used to start the local development environment using the `docker-compose-local.yml` file.
## STARTING THE SERVICES LOCALLY
Run the following command in the root of the project to start both the IRIS and Web Gateway services:
```bash
./start-local.sh
```

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