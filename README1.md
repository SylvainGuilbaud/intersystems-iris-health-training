# intersystems-iris-health-training

InterSystems IRIS for Health training project with:

- ADT and ORU interoperability flows
- shared lookup table transcoding used by multiple transforms
- local and AWS deployment workflows
- two test clients (Python desktop + Angular web app)

## Current Architecture

The main deployment in [docker-compose.yml](docker-compose.yml) runs 4 services:

- iris-dev
- iris-prod
- webgateway
- nginx

Traffic model:

- nginx serves Angular static files on /app/
- nginx proxies all other paths to webgateway
- webgateway routes CSP traffic to IRIS (dev/prod)

The local development stack in [docker-compose-local.yml](docker-compose-local.yml) uses Community Edition images for iris-dev/iris-prod and includes webgateway.

## Key Features Added

### 1) Shared Lookup-Driven Transcoding

Lookup tables are centralized in IRIS and reused across ADT and ORU transforms:

- [iris/src/DGLAB/lookup/Titles.xml](iris/src/DGLAB/lookup/Titles.xml)
- [iris/src/DGLAB/lookup/Gender.xml](iris/src/DGLAB/lookup/Gender.xml)
- [iris/src/DGLAB/lookup/PatientClasses.xml](iris/src/DGLAB/lookup/PatientClasses.xml)

DTLs using these shared tables:

- [iris/src/DGLAB/transfo/IHEPAM/seances.cls](iris/src/DGLAB/transfo/IHEPAM/seances.cls)
- [iris/src/DGLAB/transfo/ORU/transcodage.cls](iris/src/DGLAB/transfo/ORU/transcodage.cls)

Highlights:

- Title mapping uses real HL7 civility field PID-5.5
- Gender normalization uses PID-8
- Patient class normalization uses PV1-2
- ADT session-stay logic handles PV1-51 (visit/account behavior)

### 2) Raw HL7 Override in Both Test Clients

Both clients can send any pasted message as-is, independently from form fields:

- Python app: [iris/python/DGLAB.py](iris/python/DGLAB.py)
- Angular app: [iris/angular/src/app/app.component.ts](iris/angular/src/app/app.component.ts)

This is useful for replaying real-world payloads and regression tests.

### 3) ORU Routing and Transform Wiring

Router updates in [iris/src/DGLAB/router/HL7.cls](iris/src/DGLAB/router/HL7.cls) apply ORU transcoding before outbound routing targets.

### 4) Cloud Angular Deployment

Angular cloud build/deploy is automated by [build-cloud-angular.sh](build-cloud-angular.sh).

Supporting files:

- [iris/angular/angular.json](iris/angular/angular.json) (cloud build config)
- [nginx/nginx.conf](nginx/nginx.conf) (serve /app + proxy to webgateway)

## IRIS Build and Import

The IRIS image is built from [iris/Dockerfile](iris/Dockerfile).

Initialization script [iris/iris.script](iris/iris.script) imports and compiles source, then loads schemas and lookup tables.

## Quick Start

### Local (Community Edition)

```bash
./start-local.sh
```

Stop:

```bash
./stop-local.sh
```

### Full Stack (non-local profile)

```bash
./start.sh
```

Stop:

```bash
./stop.sh
```

## Angular Test App

Run the Angular app locally with proxy config:

```bash
./launch_app.sh
```

## Cloud Deployment Helpers

- Build and deploy Angular assets to AWS:

```bash
./build-cloud-angular.sh
```

- Build only:

```bash
./build-cloud-angular.sh --local
```

- SSH/SCP helpers:

- [ssh.sh](ssh.sh)
- [scp.sh](scp.sh)
- [cloudenv](cloudenv)

## Notes

- Ensure your .env values are set correctly before startup.
- Place the IRIS key in [iris/key/iris.key](iris/key/iris.key).
- Persistent data uses Docker volumes; startup scripts create/fix required permissions.