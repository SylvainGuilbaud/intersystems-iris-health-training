---
name: iris-for-health
description: "Use when working with InterSystems IRIS for Health in this repository: bootstrapping containers, importing source, troubleshooting startup, validating HL7 flows, or running the training clients."
argument-hint: What IRIS for Health task should I handle?
---

# IRIS for Health

## When to use this skill

Use this skill for repository-specific work involving the InterSystems IRIS for Health training environment, including:

- starting or stopping local or cloud-based stacks
- importing, compiling, or reloading classes and data
- troubleshooting IRIS startup, namespaces, or Docker networking
- validating ADT/ORU/HL7 behavior or SQL gateway setup
- launching the Python or Angular training clients

## Core workflow

1. Clarify the objective
   - Identify whether the request is about bootstrap, troubleshooting, code import, deployment, or validation.
   - If the target environment is not explicit, ask whether the user means community, local full stack, or AWS/cloud.

2. Identify the right entry point
   - Prefer the repository scripts in the root folder:
     - start-community.sh / start-community.ps1 for the community/local stack
     - start.sh / start.ps1 for the full stack
     - stop-*.sh / stop-*.ps1 to shut down the environment
     - launch_client_app.sh / launch_web_app.sh for the clients
   - For code changes, inspect the IRIS build flow in iris/Dockerfile and iris/iris.script.

3. Start or inspect the environment
   - Check the relevant Docker Compose files and environment variables before starting services.
   - If the stack is already running, verify container health and recent logs before making changes.
   - If the issue is network-related, inspect host names, ports, and the relevant gateway or proxy configuration.

4. Verify initialization and imports
   - Confirm that the IRIS bootstrap script runs the expected imports and compiles the source tree.
   - If classes or lookup tables changed, ensure they are re-imported or the container is rebuilt as needed.
   - Check that the expected namespaces, CSP applications, and SQL gateways are present.

5. Diagnose the problem using the repo conventions
   - Review the relevant source under iris/src and the startup script in iris/iris.script.
   - Inspect runtime logs such as DGLAB.log when the issue affects the training clients.
   - Prefer the smallest change that addresses the root cause rather than patching symptoms.

6. Validate the result
   - Confirm that the intended service, namespace, or client behavior is working.
   - If the task affects HL7 processing, send a sample message through the relevant client or test flow.
   - If the task affects deployment, verify the expected route or container state.

## Decision points

- If the request is about bringing up the environment, start with the appropriate startup script rather than editing IRIS code first.
- If the request is about code changes under iris/src, inspect the import and build flow before changing runtime state.
- If the issue appears in the web or desktop client, check the client scripts and their request URLs before assuming a server-side error.
- If the issue appears to be infra-related, inspect Docker, networking, and environment variables before debugging classes or transforms.

## Completion checklist

A task is complete when all of the following are true:

- The requested environment is running or stopped as intended.
- Relevant IRIS initialization steps completed without blocking errors.
- The affected namespace, class, or route is available and behaves as expected.
- Validation was performed with a concrete check such as a sample request, client launch, or log review.
- Any follow-up action or next step is documented clearly.

## Useful repository anchors

- README for architecture and quick-start commands
- iris/iris.script for initialization and import logic
- iris/Dockerfile for the image build process
- iris/src for the application classes, routes, and transforms
- start-community.sh, start.sh, launch_client_app.sh, and launch_web_app.sh for operational entry points

## Example prompts

- "Bootstrap the local IRIS community stack and verify it is healthy."
- "Troubleshoot the IRIS startup script and fix the import sequence."
- "Validate the HL7 ADT/ORU flow end to end in this repository."
- "Help me launch the Angular training client against the correct environment."
