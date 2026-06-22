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

### 3) DGLAB Desktop Client Features

The Python/Tkinter desktop client [iris/python/DGLAB.py](iris/python/DGLAB.py) provides:

- **Login gate** with prefilled demo credentials (testuser / IRIS)
- **Target IRIS instance selector** (6 options: dev-community, prod-community, dev-local, prod-local, dev, prod)
- **Logout flow** returning to login gate
- **Environment-specific URL routing**:
  - Each environment maps to unique IRIS instance path and superserver port
  - AWS dev/prod differentiated by instance segment (iris-health-training-dev vs iris-health-training-prod)
- **Editable namespace dropdown** (default: DGLAB, alphabetically sorted)
- **Base URL editing** with namespace-aware composition
- **Active environment badge** in UI + structured logging (TARGET=[env host:port])
- **Error highlighting** in response log (red background for HTTP errors, FAILED messages)
- **HL7 message generation** (ORU/ADT) with random patient data or raw message override
- **MLLP and HTTP senders** with retry logic, threading, and load testing (configurable message count/thread count)
- **Standardized logging** with environment/target metadata to DGLAB.log

### 4) Angular Web Client Features

The Angular standalone app [iris/angular/src/app/app.component.ts](iris/angular/src/app/app.component.ts) with Vite bundler provides:

- **Dynamic environment selection** (cloud-only or local-only based on deployment hostname)
- **Namespace dropdown** with alphabetically sorted options
- **Environment-specific Base URLs**:
  - Cloud: direct webgateway paths (e.g., `/iris-health-training-dev/csp/healthshare/...`)
  - Local: proxy-prefixed paths (e.g., `/irisaws/iris-health-training-dev/csp/healthshare/...`)
  - Community/local: port-based proxies (e.g., `/iris881/...`, `/iris80/...`)
- **ORU/ADT HTTP senders** with credential-aware requests
- **Raw message override** for regression testing
- **Load testing** with configurable message count and concurrency
- **Real-time response logging** with timestamps and error/success indicators

### 5) ORU Routing and Transform Wiring

Router updates in [iris/src/DGLAB/router/HL7.cls](iris/src/DGLAB/router/HL7.cls) apply ORU transcoding before outbound routing targets.

### 6) Cloud Angular Deployment

Angular cloud build/deploy is automated by [build-cloud-angular.sh](build-cloud-angular.sh).

Supporting files:

- [iris/angular/angular.json](iris/angular/angular.json) (cloud build config)
- [nginx/nginx.conf](nginx/nginx.conf) (serve /app + proxy to webgateway)

## IRIS Build and Import

The IRIS image is built from [iris/Dockerfile](iris/Dockerfile).

Initialization script [iris/iris.script](iris/iris.script) imports and compiles source, then loads schemas and lookup tables.

## Quick Start

### Local (Community Edition)

**Linux/macOS:**
```bash
./start-community.sh
```

**Windows (PowerShell):**
```powershell
.\start-community.ps1
```

Stop:

**Linux/macOS:**
```bash
./stop-community.sh
```

**Windows (PowerShell):**
```powershell
.\stop-community.ps1
```

### Full Stack (non-local profile)

**Linux/macOS:**
```bash
./start.sh
```

**Windows (PowerShell):**
```powershell
.\start.ps1
```

Stop:

**Linux/macOS:**
```bash
./stop.sh
```

**Windows (PowerShell):**
```powershell
.\stop.ps1
```

## Test Clients

### DGLAB Desktop Client (Python/Tkinter)

Run the Python desktop client locally:

**Linux/macOS:**
```bash
./launch_client_app.sh
```

**Windows (PowerShell):**
```powershell
.\launch_client_app.ps1
```

### Angular Web Client

Run the Angular app locally with proxy config:

**Linux/macOS:**
```bash
./launch_web_app.sh
```

**Windows (PowerShell):**
```powershell
.\launch_web_app.ps1
```

## Utility Scripts

### Set Volume Permissions

Set correct permissions on persistent Docker volumes:

**Linux/macOS:**
```bash
./create_volumes_with_permissions.sh [instance_name]
```

**Windows (PowerShell):**
```powershell
.\create_volumes_with_permissions.ps1 [instance_name]
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